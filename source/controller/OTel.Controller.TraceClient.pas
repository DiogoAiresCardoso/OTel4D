unit OTel.Controller.TraceClient;

interface

uses
  OTel.Model.Dto.Configuration, OTel.Model.Dto.Span, OTel.Model.Dto.Log,
  OTel.Controller.Trace, OTel.Controller.Logger, OTel.Controller.BatchedSignal,
  OTel.Controller.Meter, OTel.Controller.MetricReader;

type
  TOTelTraceClient = class
  strict private
    FTrace: TOTelBatchedSignal<TOTelSpanData>;
    FLogs: TOTelBatchedSignal<TOTelLogData>;
    FMetrics: TOTelMetricReader;
    FLogSettings, FMetricSettings: TOTelSignalSettings;
    FMetricInterval: Integer;
    FService: string;
    FDisabled, FClosing: Boolean;
    class function SignalActive(const Settings: TOTelSignalSettings): Boolean; static;
    class function SignalEndpoint(const Settings: TOTelSignalSettings; const Suffix: string): string; static;
    procedure Close;
  public
    constructor Create(const Config: TOTelConfiguration);
    destructor Destroy; override;
    function GetTracer(const ScopeName: string; const ScopeVersion: string = ''): TOTelTracer;
    function GetLogger(const ScopeName: string; const ScopeVersion: string = ''): TOTelLogger;
    function GetMeter(const ScopeName: string; const ScopeVersion: string = ''): TOTelMeter;
    function ForceFlush(TimeoutMs: Cardinal = 10000): Boolean;
    function Shutdown(TimeoutMs: Cardinal = 10000): Boolean;
    function DroppedSpans: Int64;
    function RejectedSpans: Int64;
    function DeliveryWarnings: Int64;
    function DroppedLogs: Int64;
    function RejectedLogs: Int64;
    function LogDeliveryWarnings: Int64;
    function RejectedMetricPoints: Int64;
    function MetricDeliveryWarnings: Int64;
    function InvalidMetricMeasurements: Int64;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, Winapi.Windows, OTel.Model.Dto.Telemetry,
  OTel.Model.Service.MetricStore, OTel.View.TraceEndpoint, OTel.View.TraceProtobuf, OTel.View.LogProtobuf;

constructor TOTelTraceClient.Create(const Config: TOTelConfiguration);
begin
  inherited Create;
  if Config = nil then raise EArgumentNilException.Create('Config must be assigned.');
  FService := Config.ServiceName;
  FDisabled := Config.SdkDisabled;
  FLogSettings := TOTelSignalSettings.Create;
  FLogSettings.Assign(Config.Additional.Logs);
  FMetricSettings := TOTelSignalSettings.Create;
  FMetricSettings.Assign(Config.Additional.Metrics);
  FMetricInterval := Config.Additional.MetricsIntervalMs;
  if FMetricInterval <= 0 then FMetricInterval := 60000;
  FTrace := TOTelBatchedSignal<TOTelSpanData>.Create(FService, Config.TracesEndpoint,
    Config.TraceHeaders, Config.TraceTimeoutMs, FDisabled,
    function(const Service: string; Batch: TObjectList<TOTelSpanData>): TBytes
    begin
      Result := TOTelTraceProtobuf.Encode(Service, Batch);
    end);
end;

destructor TOTelTraceClient.Destroy;
begin
  Close;
  FMetrics.Free;
  FLogs.Free;
  FTrace.Free;
  FMetricSettings.Free;
  FLogSettings.Free;
  inherited;
end;

class function TOTelTraceClient.SignalActive(const Settings: TOTelSignalSettings): Boolean;
begin
  if (Settings.Exporter = '') or SameText(Settings.Exporter, 'otlp') then Exit(True);
  if SameText(Settings.Exporter, 'none') then Exit(False);
  raise EOTelConfiguration.Create('The supported signal exporters are otlp and none.');
end;

class function TOTelTraceClient.SignalEndpoint(const Settings: TOTelSignalSettings; const Suffix: string): string;
var
  Base: string;
begin
  if (Settings.Protocol <> '') and not SameText(Settings.Protocol, 'http/protobuf') then
    raise EOTelConfiguration.Create('The supported OTLP protocol is http/protobuf.');
  Base := Settings.BaseEndpoint;
  if Base = '' then Base := 'http://localhost:4318';
  Result := TTraceEndpointView.RenderSignal(Base, Settings.Endpoint, Suffix);
end;

procedure TOTelTraceClient.Close;
begin
  TMonitor.Enter(Self);
  try
    FClosing := True;
    if Assigned(FTrace) then FTrace.Close;
    if Assigned(FLogs) then FLogs.Close;
    if Assigned(FMetrics) then FMetrics.Close;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTraceClient.GetTracer(const ScopeName, ScopeVersion: string): TOTelTracer;
begin
  Result := TOTelTracer.Create(FTrace.Sink, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.GetLogger(const ScopeName, ScopeVersion: string): TOTelLogger;
var
  Sink: IOTelSink<TOTelLogData>;
  Timeout: Integer;
begin
  TMonitor.Enter(Self);
  try
    if not FDisabled and not FClosing then
      if SignalActive(FLogSettings) then
      begin
        if not Assigned(FLogs) then
        begin
          Timeout := FLogSettings.TimeoutMs;
          if Timeout < 0 then Timeout := 10000;
          FLogs := TOTelBatchedSignal<TOTelLogData>.Create(FService,
            SignalEndpoint(FLogSettings, 'v1/logs'), FLogSettings.Headers, Timeout, False,
            function(const Service: string; Batch: TObjectList<TOTelLogData>): TBytes
            begin
              Result := TOTelLogProtobuf.Encode(Service, Batch);
            end);
        end;
        Sink := FLogs.Sink;
      end;
  finally
    TMonitor.Exit(Self);
  end;
  Result := TOTelLogger.Create(Sink, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.GetMeter(const ScopeName, ScopeVersion: string): TOTelMeter;
var
  Handle: IOTelMetricStore;
  Timeout: Integer;
begin
  TMonitor.Enter(Self);
  try
    if not FDisabled and not FClosing then
      if SignalActive(FMetricSettings) then
      begin
        if not Assigned(FMetrics) then
        begin
          Timeout := FMetricSettings.TimeoutMs;
          if Timeout < 0 then Timeout := 10000;
          FMetrics := TOTelMetricReader.Create(FService, SignalEndpoint(FMetricSettings, 'v1/metrics'),
            FMetricSettings.Headers, Timeout, FMetricInterval);
        end;
        Handle := FMetrics.Handle;
      end;
  finally
    TMonitor.Exit(Self);
  end;
  Result := TOTelMeter.Create(Handle, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.ForceFlush(TimeoutMs: Cardinal): Boolean;
var
  Deadline: UInt64;
  TraceTarget, LogTarget, MetricTarget: Int64;
  Metrics: TOTelMetricReader;
  Logs: TOTelBatchedSignal<TOTelLogData>;
begin
  Deadline := GetTickCount64 + TimeoutMs;
  TMonitor.Enter(Self);
  try
    TraceTarget := FTrace.Queue.RequestFlush;
    Logs := FLogs;
    LogTarget := 0;
    if Assigned(Logs) then LogTarget := Logs.Queue.RequestFlush;
    Metrics := FMetrics;
    MetricTarget := 0;
    if Assigned(Metrics) then MetricTarget := Metrics.Store.RequestFlush;
  finally
    TMonitor.Exit(Self);
  end;
  Result := FTrace.Queue.WaitFor(TraceTarget, Deadline);
  if Assigned(Logs) then
    if not Logs.Queue.WaitFor(LogTarget, Deadline) then Result := False;
  if Assigned(Metrics) then
    if not Metrics.Store.WaitFor(MetricTarget, Deadline) then Result := False;
end;

function TOTelTraceClient.Shutdown(TimeoutMs: Cardinal): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := GetTickCount64 + TimeoutMs;
  Close;
  Result := FTrace.Drain(Deadline);
  if Assigned(FLogs) then
    if not FLogs.Drain(Deadline) then Result := False;
  if Assigned(FMetrics) then
    if not FMetrics.Drain(Deadline) then Result := False;
end;

function TOTelTraceClient.DroppedSpans: Int64;
begin
  Result := FTrace.Queue.Dropped;
end;

function TOTelTraceClient.RejectedSpans: Int64;
begin
  Result := FTrace.Queue.Rejected;
end;

function TOTelTraceClient.DeliveryWarnings: Int64;
begin
  Result := FTrace.Queue.Warnings;
end;

function TOTelTraceClient.DroppedLogs: Int64;
begin
  if Assigned(FLogs) then Result := FLogs.Queue.Dropped else Result := 0;
end;

function TOTelTraceClient.RejectedLogs: Int64;
begin
  if Assigned(FLogs) then Result := FLogs.Queue.Rejected else Result := 0;
end;

function TOTelTraceClient.LogDeliveryWarnings: Int64;
begin
  if Assigned(FLogs) then Result := FLogs.Queue.Warnings else Result := 0;
end;

function TOTelTraceClient.RejectedMetricPoints: Int64;
begin
  if Assigned(FMetrics) then Result := FMetrics.Store.Rejected else Result := 0;
end;

function TOTelTraceClient.MetricDeliveryWarnings: Int64;
begin
  if Assigned(FMetrics) then Result := FMetrics.Store.Warnings else Result := 0;
end;

function TOTelTraceClient.InvalidMetricMeasurements: Int64;
begin
  if Assigned(FMetrics) then Result := FMetrics.Store.Invalid else Result := 0;
end;

end.
