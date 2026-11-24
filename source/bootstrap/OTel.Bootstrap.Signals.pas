unit OTel.Bootstrap.Signals;

interface

uses
  OTel.Application.Ports, OTel.Model.Dto.Configuration, OTel.Model.Dto.Span, OTel.Model.Dto.Log,
  OTel.Model.Dto.Metric, OTel.Transport.Contracts;

type
  TOTelSignalFactory = class(TInterfacedObject, IOTelSignalFactory)
  strict private
    FClock: IOTelClock;
    FEndpoint: IOTelEndpointResolver;
    FTrace: IOTelExporter<TOTelSpanData>;
    FLogs: IOTelExporter<TOTelLogData>;
    FMetrics: IOTelExporter<TOTelMetricPoint>;
    FMetricInterval: Integer;
    function OptionalTransport(const Settings: TOTelSignalSettings; const Suffix: string): IOTelRequestTransport;
    function CreateTrace: IOTelBatchSignal<TOTelSpanData>;
    function CreateLogs: IOTelBatchSignal<TOTelLogData>;
    function CreateMetrics: IOTelMetricSignal;
  public
    constructor Create(const Config: TOTelConfiguration; const Clock: IOTelClock;
      const Endpoint: IOTelEndpointResolver);
  end;

implementation

uses
  System.SysUtils, OTel.Controller.BatchedSignal,
  OTel.Controller.MetricReader, OTel.Transport.Http, OTel.Otlp.Exporter,
  OTel.View.TraceProtobuf, OTel.View.LogProtobuf, OTel.View.MetricProtobuf, OTel.View.ProtobufResponse;

constructor TOTelSignalFactory.Create(const Config: TOTelConfiguration; const Clock: IOTelClock;
      const Endpoint: IOTelEndpointResolver);
var
  Transport: IOTelRequestTransport;
  TraceEncoder: IOTelBatchEncoder<TOTelSpanData>;
  LogEncoder: IOTelBatchEncoder<TOTelLogData>;
  MetricEncoder: IOTelBatchEncoder<TOTelMetricPoint>;
  Decoder: IOTelResponseDecoder;
begin
  inherited Create;
  FClock := Clock;
  FEndpoint := Endpoint;
  if Config.SdkDisabled then Exit;
  FMetricInterval := Config.Additional.MetricsIntervalMs;
  if FMetricInterval <= 0 then FMetricInterval := 60000;

  Decoder := TOTelProtobufResponse.Create;
  Transport := TOTelHttpTransport.Create(Config.TracesEndpoint, Config.TraceHeaders, Clock, Decoder,
    Config.TraceTimeoutMs);
  TraceEncoder := TOTelTraceProtobuf.Create;
  FTrace := TOTelOtlpExporter<TOTelSpanData>.Create(Transport, TraceEncoder, Config.ServiceName);

  Transport := OptionalTransport(Config.Additional.Logs, 'v1/logs');
  if Assigned(Transport) then
  begin
    LogEncoder := TOTelLogProtobuf.Create;
    FLogs := TOTelOtlpExporter<TOTelLogData>.Create(Transport, LogEncoder, Config.ServiceName);
  end;

  Transport := OptionalTransport(Config.Additional.Metrics, 'v1/metrics');
  if Assigned(Transport) then
  begin
    MetricEncoder := TOTelMetricProtobuf.Create;
    FMetrics := TOTelOtlpExporter<TOTelMetricPoint>.Create(Transport, MetricEncoder, Config.ServiceName);
  end;
end;

function TOTelSignalFactory.OptionalTransport(const Settings: TOTelSignalSettings;
  const Suffix: string): IOTelRequestTransport;
var
  BaseEndpoint, Endpoint: string;
  Timeout: Integer;
  Decoder: IOTelResponseDecoder;
begin
  Result := nil;
  if SameText(Settings.Exporter, 'none') then Exit;
  if (Settings.Exporter <> '') and not SameText(Settings.Exporter, 'otlp') then
    raise EOTelConfiguration.Create('The supported signal exporters are otlp and none.');
  if (Settings.Protocol <> '') and not SameText(Settings.Protocol, 'http/protobuf') then
    raise EOTelConfiguration.Create('The supported OTLP protocol is http/protobuf.');
  BaseEndpoint := Settings.BaseEndpoint;
  if BaseEndpoint = '' then BaseEndpoint := 'http://localhost:4318';
  Endpoint := FEndpoint.RenderSignal(BaseEndpoint, Settings.Endpoint, Suffix);
  Timeout := Settings.TimeoutMs;
  if Timeout < 0 then Timeout := 10000;
  Decoder := TOTelProtobufResponse.Create;
  Result := TOTelHttpTransport.Create(Endpoint, Settings.Headers, FClock, Decoder, Timeout);
end;

function TOTelSignalFactory.CreateTrace: IOTelBatchSignal<TOTelSpanData>;
begin
  Result := TOTelBatchedSignal<TOTelSpanData>.Create(FTrace, FClock);
end;

function TOTelSignalFactory.CreateLogs: IOTelBatchSignal<TOTelLogData>;
begin
  if Assigned(FLogs) then Result := TOTelBatchedSignal<TOTelLogData>.Create(FLogs, FClock)
  else Result := nil;
end;

function TOTelSignalFactory.CreateMetrics: IOTelMetricSignal;
begin
  if Assigned(FMetrics) then Result := TOTelMetricReader.Create(FMetrics, FClock, FMetricInterval)
  else Result := nil;
end;

end.
