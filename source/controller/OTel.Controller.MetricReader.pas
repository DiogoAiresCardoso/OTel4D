unit OTel.Controller.MetricReader;

interface

uses
  System.Classes, System.SyncObjs, OTel.Model.Service.MetricStore, OTel.Transport.Http;

type
  TOTelMetricReader = class
  strict private
    FStore: TOTelMetricStore;
    FHandle: IOTelMetricStore;
    FTransport: TOTelHttpTransport;
    FAbort: TEvent;
    FWorker: TThread;
  public
    constructor Create(const Service, Endpoint, Headers: string; TimeoutMs, IntervalMs: Integer);
    destructor Destroy; override;
    procedure Close;
    function Drain(Deadline: UInt64): Boolean;
    property Store: TOTelMetricStore read FStore;
    property Handle: IOTelMetricStore read FHandle;
  end;

implementation

uses
  Winapi.Windows, OTel.Controller.MetricWorker;

constructor TOTelMetricReader.Create(const Service, Endpoint, Headers: string; TimeoutMs, IntervalMs: Integer);
begin
  inherited Create;
  FStore := TOTelMetricStore.Create;
  FHandle := FStore;
  FAbort := TEvent.Create(nil, True, False, '');
  FTransport := TOTelHttpTransport.Create(Endpoint, Headers, FAbort, TimeoutMs);
  FWorker := TMetricWorker.Create(FStore, FTransport, IntervalMs, Service);
  FWorker.Start;
end;

destructor TOTelMetricReader.Destroy;
begin
  Close;
  if Assigned(FWorker) then
  begin
    if WaitForSingleObject(FWorker.Handle, 0) = WAIT_TIMEOUT then FAbort.SetEvent;
    FWorker.Free;
  end;
  FTransport.Free;
  FAbort.Free;
  FHandle := nil;
  inherited;
end;

procedure TOTelMetricReader.Close;
begin
  if Assigned(FStore) then FStore.Close;
end;

function TOTelMetricReader.Drain(Deadline: UInt64): Boolean;
var
  Tick: UInt64;
  WaitMs: Cardinal;
begin
  Tick := GetTickCount64;
  WaitMs := 0;
  if Tick < Deadline then WaitMs := Cardinal(Deadline - Tick);
  if WaitForSingleObject(FWorker.Handle, WaitMs) <> WAIT_OBJECT_0 then Exit(False);
  Result := FStore.WaitFor(FStore.RequestFlush, Deadline);
end;

end.
