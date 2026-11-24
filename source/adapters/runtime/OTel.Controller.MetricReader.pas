unit OTel.Controller.MetricReader;

interface

uses
  OTel.Application.Ports, OTel.Model.Dto.Metric, OTel.Runtime.Contracts;

type
  TOTelMetricReader = class(TInterfacedObject, IOTelMetricSignal)
  strict private
    FAggregation: IOTelMetricAggregation;
    FExporter: IOTelExporter<TOTelMetricPoint>;
    FWorker: IOTelBackgroundWorker;
    FClock: IOTelClock;
    function Store: IOTelMetricAggregation;
    procedure Close;
    function Drain(Deadline: UInt64): Boolean;
  public
    constructor Create(const Exporter: IOTelExporter<TOTelMetricPoint>; const Clock: IOTelClock;
      IntervalMs: Integer);
    destructor Destroy; override;
  end;

implementation

uses
  OTel.Model.Service.MetricStore, OTel.Controller.MetricWorker, OTel.Runtime.BackgroundWorker;

constructor TOTelMetricReader.Create(const Exporter: IOTelExporter<TOTelMetricPoint>;
  const Clock: IOTelClock; IntervalMs: Integer);
var
  Task: IOTelWorkerTask;
begin
  inherited Create;
  FClock := Clock;
  FExporter := Exporter;
  FAggregation := TOTelMetricStore.Create(Clock);
  Task := TMetricWorker.Create(FAggregation, Exporter, Clock, IntervalMs);
  FWorker := TOTelBackgroundWorker.Create(Task, Clock);
end;

destructor TOTelMetricReader.Destroy;
begin
  Close;
  if Assigned(FWorker) and not FWorker.WaitUntil(FClock.MonotonicMs) then FExporter.Cancel;
  FWorker := nil;
  inherited;
end;

function TOTelMetricReader.Store: IOTelMetricAggregation;
begin
  Result := FAggregation;
end;

procedure TOTelMetricReader.Close;
begin
  if Assigned(FAggregation) then FAggregation.Close;
end;

function TOTelMetricReader.Drain(Deadline: UInt64): Boolean;
begin
  if not FWorker.WaitUntil(Deadline) then Exit(False);
  Result := FAggregation.WaitFor(FAggregation.RequestFlush, Deadline);
end;

end.
