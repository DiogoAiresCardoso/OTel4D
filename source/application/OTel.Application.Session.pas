unit OTel.Application.Session;

interface

uses
  OTel.Application.Ports, OTel.Model.Dto.Telemetry, OTel.Model.Dto.Log, OTel.Model.Dto.Span;

type
  TOTelTelemetrySession = class(TInterfacedObject, IOTelSession)
  strict private
    FClock: IOTelClock;
    FFactory: IOTelSignalFactory;
    FTrace: IOTelBatchSignal<TOTelSpanData>;
    FLogs: IOTelBatchSignal<TOTelLogData>;
    FMetrics: IOTelMetricSignal;
    FClosing: Boolean;
    procedure Close;
    function TraceSink: IOTelSink<TOTelSpanData>;
    function LogSink: IOTelSink<TOTelLogData>;
    function Metrics: IOTelMetricStore;
    function ForceFlush(TimeoutMs: Cardinal): Boolean;
    function Shutdown(TimeoutMs: Cardinal): Boolean;
    function DroppedSpans: Int64;
    function RejectedSpans: Int64;
    function DeliveryWarnings: Int64;
    function DroppedLogs: Int64;
    function RejectedLogs: Int64;
    function LogDeliveryWarnings: Int64;
    function RejectedMetricPoints: Int64;
    function MetricDeliveryWarnings: Int64;
    function InvalidMetricMeasurements: Int64;
  public
    constructor Create(const Clock: IOTelClock; const Factory: IOTelSignalFactory);
    destructor Destroy; override;
  end;

implementation

constructor TOTelTelemetrySession.Create(const Clock: IOTelClock; const Factory: IOTelSignalFactory);
begin
  inherited Create;
  FClock := Clock;
  FFactory := Factory;
  FTrace := FFactory.CreateTrace;
end;

destructor TOTelTelemetrySession.Destroy;
begin
  Close;
  FMetrics := nil;
  FLogs := nil;
  FTrace := nil;
  inherited;
end;

procedure TOTelTelemetrySession.Close;
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

function TOTelTelemetrySession.TraceSink: IOTelSink<TOTelSpanData>;
begin
  Result := FTrace.Queue;
end;

function TOTelTelemetrySession.LogSink: IOTelSink<TOTelLogData>;
begin
  Result := nil;
  TMonitor.Enter(Self);
  try
    if FClosing then Exit;
    if not Assigned(FLogs) then FLogs := FFactory.CreateLogs;
    if Assigned(FLogs) then Result := FLogs.Queue;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.Metrics: IOTelMetricStore;
begin
  Result := nil;
  TMonitor.Enter(Self);
  try
    if FClosing then Exit;
    if not Assigned(FMetrics) then FMetrics := FFactory.CreateMetrics;
    if Assigned(FMetrics) then Result := FMetrics.Store;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.ForceFlush(TimeoutMs: Cardinal): Boolean;
var
  Deadline: UInt64;
  TraceTarget, LogTarget, MetricTarget: Int64;
  Metrics: IOTelMetricSignal;
  Logs: IOTelBatchSignal<TOTelLogData>;
begin
  Deadline := FClock.MonotonicMs + TimeoutMs;
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

function TOTelTelemetrySession.Shutdown(TimeoutMs: Cardinal): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := FClock.MonotonicMs + TimeoutMs;
  Close;
  Result := FTrace.Drain(Deadline);
  if Assigned(FLogs) then
    if not FLogs.Drain(Deadline) then Result := False;
  if Assigned(FMetrics) then
    if not FMetrics.Drain(Deadline) then Result := False;
end;

function TOTelTelemetrySession.DroppedSpans: Int64;
begin
  Result := FTrace.Queue.Dropped;
end;

function TOTelTelemetrySession.RejectedSpans: Int64;
begin
  Result := FTrace.Queue.Rejected;
end;

function TOTelTelemetrySession.DeliveryWarnings: Int64;
begin
  Result := FTrace.Queue.Warnings;
end;

function TOTelTelemetrySession.DroppedLogs: Int64;
begin
  TMonitor.Enter(Self);
  try
    if Assigned(FLogs) then Result := FLogs.Queue.Dropped else Result := 0;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.RejectedLogs: Int64;
begin
  TMonitor.Enter(Self);
  try
    if Assigned(FLogs) then Result := FLogs.Queue.Rejected else Result := 0;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.LogDeliveryWarnings: Int64;
begin
  TMonitor.Enter(Self);
  try
    if Assigned(FLogs) then Result := FLogs.Queue.Warnings else Result := 0;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.RejectedMetricPoints: Int64;
begin
  TMonitor.Enter(Self);
  try
    if Assigned(FMetrics) then Result := FMetrics.Store.Rejected else Result := 0;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.MetricDeliveryWarnings: Int64;
begin
  TMonitor.Enter(Self);
  try
    if Assigned(FMetrics) then Result := FMetrics.Store.Warnings else Result := 0;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelTelemetrySession.InvalidMetricMeasurements: Int64;
begin
  TMonitor.Enter(Self);
  try
    if Assigned(FMetrics) then Result := FMetrics.Store.Invalid else Result := 0;
  finally
    TMonitor.Exit(Self);
  end;
end;

end.
