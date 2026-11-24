unit TelemetryDemo.Session;

interface

uses
  OTel.Api;

type
  TDemoTelemetrySession = class
  strict private
    FClient: TOTelTraceClient;
    FTracer: TOTelTracer;
    FLogger: TOTelLogger;
    FOperations: TOTelCounter;
    FDuration: TOTelHistogram;
    FPort: Integer;
    procedure OpenClient(Port: Integer);
    procedure CloseClient;
    function CalculateOrderTotal: Int64;
    procedure ReportOrder(const Span: TOTelSpan);
    procedure CheckDelivery;
  public
    destructor Destroy; override;
    procedure SendSample(Port: Integer; out TraceId, SpanId: string);
  end;

implementation

uses
  System.SysUtils;

const
  ServiceName = 'otel4d-delphi-demo';
  ScopeName = 'OTel4D.TelemetryDemo';
  ScopeVersion = '1.0';
  ExportTimeoutMs = 2500;
  FlushTimeoutMs = 6000;

procedure TDemoTelemetrySession.OpenClient(Port: Integer);
var
  Endpoint: string;
  Configuration: TOTelConfiguration;
  Meter: TOTelMeter;
begin
  if (Port < 1) or (Port > 65535) then
    raise EArgumentOutOfRangeException.Create('Enter a Collector port between 1 and 65535.');
  if Assigned(FClient) and (FPort = Port) then Exit;

  CloseClient;
  Endpoint := Format('http://127.0.0.1:%d', [Port]);
  // The lab uses one loopback endpoint and an explicit, credential-free snapshot.
  Configuration := TOTelConfiguration.Create(ServiceName, Endpoint + '/v1/traces', '', False, ExportTimeoutMs);
  try
    Configuration.Additional.Logs.BaseEndpoint := Endpoint;
    Configuration.Additional.LogsTimeoutMs := ExportTimeoutMs;
    Configuration.Additional.Metrics.BaseEndpoint := Endpoint;
    Configuration.Additional.MetricsTimeoutMs := ExportTimeoutMs;
    FClient := TOTelTraceClient.Create(Configuration);
  finally
    Configuration.Free;
  end;
  FTracer := FClient.GetTracer(ScopeName, ScopeVersion);
  FLogger := FClient.GetLogger(ScopeName, ScopeVersion);
  Meter := FClient.GetMeter(ScopeName, ScopeVersion);
  try
    FOperations := Meter.CreateCounter('otel4d.demo.operations', '', 'Completed demo order calculations.');
    FDuration := Meter.CreateHistogram('otel4d.demo.operation.duration', 's',
      'Time spent processing a demo order.', [0.0001, 0.001, 0.01, 0.1, 1]);
  finally
    Meter.Free;
  end;
  FPort := Port;
end;

procedure TDemoTelemetrySession.CloseClient;
begin
  FreeAndNil(FDuration);
  FreeAndNil(FOperations);
  FreeAndNil(FLogger);
  FreeAndNil(FTracer);
  if Assigned(FClient) then
  begin
    FClient.Shutdown(0);
    FreeAndNil(FClient);
  end;
  FPort := 0;
end;

destructor TDemoTelemetrySession.Destroy;
begin
  CloseClient;
  inherited;
end;

function TDemoTelemetrySession.CalculateOrderTotal: Int64;
const
  Quantity = 3;
  UnitPriceCents = 1995;
var
  Calculation: TOTelSpan;
begin
  Calculation := FTracer.StartSpan('demo.order.calculate');
  try
    Result := Quantity * UnitPriceCents;
    Calculation.SetAttribute('demo.order.quantity', Int64(Quantity));
    Calculation.SetAttribute('demo.order.total_cents', Result);
  finally
    Calculation.Free;
  end;
end;

procedure TDemoTelemetrySession.ReportOrder(const Span: TOTelSpan);
var
  Attributes: TOTelAttributes;
  TotalCents: Int64;
begin
  TotalCents := CalculateOrderTotal;
  Span.SetAttribute('demo.order.total_cents', TotalCents);
  Attributes := TOTelAttributes.Create;
  try
    Attributes.Put('demo.order.total_cents', TotalCents);
    FLogger.Emit(llInfo, 'Demo order calculated', Attributes);
  finally
    Attributes.Free;
  end;
  Span.SetStatus(ssOk);
end;

procedure TDemoTelemetrySession.CheckDelivery;
begin
  if not FClient.ForceFlush(FlushTimeoutMs) then
    raise Exception.CreateFmt(
      'Delivery incomplete. Spans: %d, logs: %d, metric points: %d unconfirmed. Check the Collector port and try again.',
      [FClient.DroppedSpans + FClient.RejectedSpans, FClient.DroppedLogs + FClient.RejectedLogs,
       FClient.RejectedMetricPoints]);
end;

procedure TDemoTelemetrySession.SendSample(Port: Integer; out TraceId, SpanId: string);
var
  Span: TOTelSpan;
  ElapsedNanos: UInt64;
begin
  TraceId := '';
  SpanId := '';
  try
    OpenClient(Port);
    Span := FTracer.StartSpan('demo.order.preview');
    try
      TraceId := Copy(Span.TraceParent, 4, 32);
      SpanId := Copy(Span.TraceParent, 37, 16);
      Span.WithContext(
        procedure
        begin
          ReportOrder(Span);
        end);
      ElapsedNanos := Span.FinishWithDuration;
    finally
      Span.Free;
    end;
    FOperations.Add(1);
    FDuration.RecordValue(ElapsedNanos / 1000000000);
    CheckDelivery;
  except
    CloseClient;
    raise;
  end;
end;

end.
