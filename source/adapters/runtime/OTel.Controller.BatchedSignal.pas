unit OTel.Controller.BatchedSignal;

interface

uses
  OTel.Application.Ports, OTel.Runtime.Contracts;

type
  TOTelBatchedSignal<T: class> = class(TInterfacedObject, IOTelBatchSignal<T>)
  strict private
    FExporter: IOTelExporter<T>;
    FWorker: IOTelBackgroundWorker;
    FBuffer: IOTelBatchQueue<T>;
    FClock: IOTelClock;
    function Queue: IOTelBatchQueue<T>;
    procedure Close;
    function Drain(Deadline: UInt64): Boolean;
  public
    constructor Create(const Exporter: IOTelExporter<T>; const Clock: IOTelClock);
    destructor Destroy; override;
  end;

implementation

uses
  OTel.Controller.SpanQueue, OTel.Controller.DeliveryWorker, OTel.Runtime.BackgroundWorker;

constructor TOTelBatchedSignal<T>.Create(const Exporter: IOTelExporter<T>; const Clock: IOTelClock);
var
  Task: IOTelWorkerTask;
begin
  inherited Create;
  FClock := Clock;
  FExporter := Exporter;
  FBuffer := TOTelBatchQueue<T>.Create(not Assigned(Exporter), Clock);
  if not Assigned(Exporter) then Exit;
  Task := TDeliveryWorker<T>.Create(FBuffer, Exporter);
  FWorker := TOTelBackgroundWorker.Create(Task, Clock);
end;

destructor TOTelBatchedSignal<T>.Destroy;
begin
  Close;
  if Assigned(FWorker) and not FWorker.WaitUntil(FClock.MonotonicMs) then FExporter.Cancel;
  FWorker := nil;
  inherited;
end;

function TOTelBatchedSignal<T>.Queue: IOTelBatchQueue<T>;
begin
  Result := FBuffer;
end;

procedure TOTelBatchedSignal<T>.Close;
begin
  if Assigned(FBuffer) then FBuffer.Close;
end;

function TOTelBatchedSignal<T>.Drain(Deadline: UInt64): Boolean;
begin
  if Assigned(FWorker) and not FWorker.WaitUntil(Deadline) then Exit(False);
  Result := FBuffer.WaitFor(FBuffer.RequestFlush, Deadline);
end;

end.
