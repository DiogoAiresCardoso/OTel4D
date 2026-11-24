unit OTel.Controller.TraceClient;

interface

uses
  OTel.Model.Dto.Configuration, OTel.Application.Ports, OTel.Controller.Trace,
  OTel.Controller.Logger, OTel.Controller.Meter;

type
  TOTelTraceClient = class
  strict private
    FSession: IOTelSession;
  public
    constructor Create(const Config: TOTelConfiguration);
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
  OTel.Bootstrap;

constructor TOTelTraceClient.Create(const Config: TOTelConfiguration);
var
  Bootstrap: IOTelBootstrap;
begin
  inherited Create;
  Bootstrap := TOTelBootstrap.Create;
  FSession := Bootstrap.Open(Config);
end;

function TOTelTraceClient.GetTracer(const ScopeName, ScopeVersion: string): TOTelTracer;
begin
  Result := TOTelTracer.Create(FSession.TraceSink, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.GetLogger(const ScopeName, ScopeVersion: string): TOTelLogger;
begin
  Result := TOTelLogger.Create(FSession.LogSink, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.GetMeter(const ScopeName, ScopeVersion: string): TOTelMeter;
begin
  Result := TOTelMeter.Create(FSession.Metrics, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.ForceFlush(TimeoutMs: Cardinal): Boolean;
begin
  Result := FSession.ForceFlush(TimeoutMs);
end;

function TOTelTraceClient.Shutdown(TimeoutMs: Cardinal): Boolean;
begin
  Result := FSession.Shutdown(TimeoutMs);
end;

function TOTelTraceClient.DroppedSpans: Int64;
begin
  Result := FSession.DroppedSpans;
end;

function TOTelTraceClient.RejectedSpans: Int64;
begin
  Result := FSession.RejectedSpans;
end;

function TOTelTraceClient.DeliveryWarnings: Int64;
begin
  Result := FSession.DeliveryWarnings;
end;

function TOTelTraceClient.DroppedLogs: Int64;
begin
  Result := FSession.DroppedLogs;
end;

function TOTelTraceClient.RejectedLogs: Int64;
begin
  Result := FSession.RejectedLogs;
end;

function TOTelTraceClient.LogDeliveryWarnings: Int64;
begin
  Result := FSession.LogDeliveryWarnings;
end;

function TOTelTraceClient.RejectedMetricPoints: Int64;
begin
  Result := FSession.RejectedMetricPoints;
end;

function TOTelTraceClient.MetricDeliveryWarnings: Int64;
begin
  Result := FSession.MetricDeliveryWarnings;
end;

function TOTelTraceClient.InvalidMetricMeasurements: Int64;
begin
  Result := FSession.InvalidMetricMeasurements;
end;

end.
