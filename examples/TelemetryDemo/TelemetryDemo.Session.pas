unit TelemetryDemo.Session;

interface

uses
  OTel.Api;

type
  TDemoScenario = (dsSuccess, dsRetry, dsRejected, dsUnavailable);

  TDemoTelemetrySession = class
  strict private
    FClient: TOTelTraceClient;
    FTracer: TOTelTracer;
    FLogger: TOTelLogger;
    FOperations: TOTelCounter;
    FInventory: TOTelCounter;
    FDuration: TOTelHistogram;
    FPort: Integer;
    procedure OpenClient(Port: Integer);
    procedure CloseClient;
    function CalculateOrderTotal(Quantity: Int64): Int64;
    procedure RejectOrder(const Attributes: TOTelAttributes);
    procedure InventoryAttempt(const Name: string; Attempt: Int64; Status: TOTelStatus;
      Level: TOTelLogLevel; const Message: string; const Attributes: TOTelAttributes);
    function RunOrder(const Span: TOTelSpan; Scenario: TDemoScenario): Int64;
    procedure CheckDelivery;
  public
    destructor Destroy; override;
    class function ScenarioCaption(Scenario: TDemoScenario): string; static;
    procedure SendSample(Port: Integer; Scenario: TDemoScenario; out TraceId, SpanId: string);
  end;

implementation

uses
  System.SysUtils;

const
  ServiceName = 'otel4d-delphi-demo';
  ScopeName = 'OTel4D.TelemetryDemo';
  ScopeVersion = '1.1';
  ExportTimeoutMs = 2500;
  FlushTimeoutMs = 6000;
  OrderQuantity = 3;
  QuantityLimit = 10;
  UnitPriceCents = 1995;
  ScenarioNames: array[TDemoScenario] of string = ('success', 'retry', 'rejected', 'unavailable');
  InventoryReserve = 'demo.inventory.reserve';
  InventoryRestock = 'demo.inventory.restock';

class function TDemoTelemetrySession.ScenarioCaption(Scenario: TDemoScenario): string;
const
  Captions: array[TDemoScenario] of string = ('Successful order', 'Recovered retry',
    'Rejected order', 'Dependency unavailable');
begin
  Result := Captions[Scenario];
end;

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
    FOperations := Meter.CreateCounter('otel4d.demo.operations', '', 'Completed demo scenario runs.');
    FInventory := Meter.CreateUpDownCounter('otel4d.demo.inventory.adjustment', '',
      'Net change in simulated stock items.');
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
  FreeAndNil(FInventory);
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

function TDemoTelemetrySession.CalculateOrderTotal(Quantity: Int64): Int64;
var
  Calculation: TOTelSpan;
begin
  Calculation := FTracer.StartSpan('demo.order.calculate');
  try
    Result := Quantity * UnitPriceCents;
    Calculation.SetAttribute('demo.order.quantity', Quantity);
    Calculation.SetAttribute('demo.order.total_cents', Result);
    Calculation.SetAttribute('demo.order.unit_price', UnitPriceCents / 100);
    Calculation.AddEvent('order.total.calculated');
    Calculation.SetStatus(ssOk);
  finally
    Calculation.Free;
  end;
end;

procedure TDemoTelemetrySession.RejectOrder(const Attributes: TOTelAttributes);
var
  Validation: TOTelSpan;
begin
  Validation := FTracer.StartSpan('demo.order.validate');
  try
    Validation.SetAttribute('demo.order.quantity_limit', Int64(QuantityLimit));
    Validation.SetStatus(ssError, 'Order quantity exceeds the demo limit');
    Validation.AddEvent('order.rejected');
    Validation.WithContext(
      procedure
      begin
        FLogger.Emit(llError, 'Order quantity exceeds the demo limit', Attributes);
      end);
  finally
    Validation.Free;
  end;
end;

procedure TDemoTelemetrySession.InventoryAttempt(const Name: string; Attempt: Int64;
  Status: TOTelStatus; Level: TOTelLogLevel; const Message: string;
  const Attributes: TOTelAttributes);
var
  Inventory: TOTelSpan;
begin
  Inventory := FTracer.StartSpan(Name, skClient);
  try
    Inventory.SetAttribute('demo.attempt', Attempt);
    Inventory.SetStatus(Status, Message);
    if Status = ssError then
    begin
      Inventory.SetAttribute('error.type', 'demo.inventory.unavailable');
      Inventory.AddEvent('inventory.attempt.failed');
    end
    else
      Inventory.AddEvent('inventory.attempt.succeeded');
    Inventory.WithContext(
      procedure
      begin
        FLogger.Emit(Level, Message, Attributes);
      end);
  finally
    Inventory.Free;
  end;
end;

function TDemoTelemetrySession.RunOrder(const Span: TOTelSpan; Scenario: TDemoScenario): Int64;
var
  Attributes: TOTelAttributes;
  Quantity, TotalCents: Int64;
begin
  Result := 0;
  Quantity := OrderQuantity;
  if Scenario = dsRejected then Quantity := QuantityLimit + 1;
  Attributes := TOTelAttributes.Create;
  try
    Attributes.Put('demo.scenario', ScenarioNames[Scenario]);
    Attributes.Put('demo.simulated', True);
    Attributes.Put('demo.order.quantity', Quantity);
    Attributes.Put('demo.order.unit_price', UnitPriceCents / 100);
    FLogger.Emit(llTrace, 'Order processing started', Attributes);
    TotalCents := CalculateOrderTotal(Quantity);
    Span.SetAttribute('demo.order.total_cents', TotalCents);
    Attributes.Put('demo.order.total_cents', TotalCents);
    FLogger.Emit(llDebug, 'Order total calculated', Attributes);

    case Scenario of
      dsSuccess:
        begin
          InventoryAttempt(InventoryReserve, 1, ssOk, llDebug, 'Inventory reserved', Attributes);
          Result := -Quantity;
        end;
      dsRetry:
        begin
          InventoryAttempt(InventoryRestock, 1, ssError, llWarn, 'Inventory restock timed out', Attributes);
          Span.AddEvent('inventory.retry.scheduled');
          InventoryAttempt(InventoryRestock, 2, ssOk, llDebug, 'Inventory restocked on retry', Attributes);
          Result := Quantity;
        end;
      dsRejected:
        begin
          RejectOrder(Attributes);
          Span.SetStatus(ssError, 'Order rejected');
          Exit;
        end;
      dsUnavailable:
        begin
          InventoryAttempt(InventoryReserve, 1, ssError, llFatal, 'Inventory dependency unavailable', Attributes);
          Span.SetStatus(ssError, 'Inventory dependency unavailable');
          Exit;
        end;
    end;
    FLogger.Emit(llInfo, 'Demo order processed', Attributes);
    Span.SetStatus(ssOk);
  finally
    Attributes.Free;
  end;
end;

procedure TDemoTelemetrySession.CheckDelivery;
begin
  if not FClient.ForceFlush(FlushTimeoutMs) then
    raise Exception.CreateFmt(
      'Delivery incomplete. Spans: %d, logs: %d, metric points: %d unconfirmed. Check the Collector port and try again.',
      [FClient.DroppedSpans + FClient.RejectedSpans, FClient.DroppedLogs + FClient.RejectedLogs,
       FClient.RejectedMetricPoints]);
end;

procedure TDemoTelemetrySession.SendSample(Port: Integer; Scenario: TDemoScenario;
  out TraceId, SpanId: string);
var
  Span: TOTelSpan;
  Labels: TOTelAttributes;
  ElapsedNanos: UInt64;
  InventoryDelta: Int64;
begin
  TraceId := '';
  SpanId := '';
  try
    OpenClient(Port);
    Span := FTracer.StartSpan('demo.order.preview');
    try
      TraceId := Copy(Span.TraceParent, 4, 32);
      SpanId := Copy(Span.TraceParent, 37, 16);
      Span.SetAttribute('demo.scenario', ScenarioNames[Scenario]);
      Span.WithContext(
        procedure
        begin
          InventoryDelta := RunOrder(Span, Scenario);
        end);
      ElapsedNanos := Span.FinishWithDuration;
    finally
      Span.Free;
    end;
    Labels := TOTelAttributes.Create;
    try
      Labels.Put('demo.scenario', ScenarioNames[Scenario]);
      FOperations.Add(1, Labels);
      FInventory.Add(InventoryDelta, Labels);
      FDuration.RecordValue(ElapsedNanos / 1000000000, Labels);
    finally
      Labels.Free;
    end;
    CheckDelivery;
  except
    CloseClient;
    raise;
  end;
end;

end.
