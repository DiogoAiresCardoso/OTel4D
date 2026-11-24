unit OTel.Runtime.BackgroundWorker;

interface

uses
  System.Classes, OTel.Application.Ports, OTel.Runtime.Contracts;

type
  TOTelBackgroundWorker = class(TInterfacedObject, IOTelBackgroundWorker)
  strict private
    FClock: IOTelClock;
    FThread: TThread;
    function WaitUntil(Deadline: UInt64): Boolean;
  public
    constructor Create(const Task: IOTelWorkerTask; const Clock: IOTelClock);
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.Windows;

constructor TOTelBackgroundWorker.Create(const Task: IOTelWorkerTask; const Clock: IOTelClock);
var
  Work: IOTelWorkerTask;
begin
  inherited Create;
  FClock := Clock;
  // Capture a strong local interface. The thread must never capture the worker that joins it.
  Work := Task;
  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      Work.Execute;
    end);
  FThread.FreeOnTerminate := False;
  FThread.Start;
end;

destructor TOTelBackgroundWorker.Destroy;
begin
  FThread.Free;
  inherited;
end;

function TOTelBackgroundWorker.WaitUntil(Deadline: UInt64): Boolean;
var
  Tick: UInt64;
  WaitMs: Cardinal;
begin
  Tick := FClock.MonotonicMs;
  WaitMs := 0;
  if Tick < Deadline then WaitMs := Cardinal(Deadline - Tick);
  Result := WaitForSingleObject(FThread.Handle, WaitMs) = WAIT_OBJECT_0;
end;

end.
