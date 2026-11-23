unit OTel.Controller.BatchedSignal;

interface

uses
  System.Classes, System.SyncObjs,
  OTel.Model.Dto.Telemetry, OTel.Controller.SpanQueue, OTel.Transport.Http, Winapi.Windows,
  OTel.Controller.DeliveryWorker;

type
  TOTelBatchedSignal<T: class> = class
  strict private
    FAbort: TEvent;
    FTransport: TOTelHttpTransport;
    FWorker: TThread;
    FQueue: TOTelBatchQueue<T>;
    FSink: IOTelSink<T>;
  public
    constructor Create(const Service, Endpoint, Headers: string; TimeoutMs: Integer;
      Disabled: Boolean; const Encoder: TOTelBatchEncoder<T>);
    destructor Destroy; override;
    procedure Close;
    function Drain(Deadline: UInt64): Boolean;
    property Queue: TOTelBatchQueue<T> read FQueue;
    property Sink: IOTelSink<T> read FSink;
  end;

implementation

constructor TOTelBatchedSignal<T>.Create(const Service, Endpoint, Headers: string;
  TimeoutMs: Integer; Disabled: Boolean; const Encoder: TOTelBatchEncoder<T>);
begin
  inherited Create;
  FQueue := TOTelBatchQueue<T>.Create(Disabled);
  FSink := FQueue;
  if Disabled then Exit;
  FAbort := TEvent.Create(nil, True, False, '');
  FTransport := TOTelHttpTransport.Create(Endpoint, Headers, FAbort, TimeoutMs);
  FWorker := TDeliveryWorker<T>.Create(FQueue, FTransport, Service, Encoder);
  FWorker.Start;
end;

destructor TOTelBatchedSignal<T>.Destroy;
begin
  Close;
  if Assigned(FWorker) then
  begin
    if WaitForSingleObject(FWorker.Handle, 0) = WAIT_TIMEOUT then FAbort.SetEvent;
    FWorker.Free;
  end;
  FTransport.Free;
  FAbort.Free;
  FSink := nil;
  inherited;
end;

procedure TOTelBatchedSignal<T>.Close;
begin
  if Assigned(FQueue) then FQueue.Close;
end;

function TOTelBatchedSignal<T>.Drain(Deadline: UInt64): Boolean;
var
  NowTick: UInt64;
  WaitMs: Cardinal;
begin
  if Assigned(FWorker) then
  begin
    NowTick := GetTickCount64;
    WaitMs := 0;
    if NowTick < Deadline then WaitMs := Cardinal(Deadline - NowTick);
    if WaitForSingleObject(FWorker.Handle, WaitMs) <> WAIT_OBJECT_0 then Exit(False);
  end;
  Result := FQueue.WaitFor(FQueue.RequestFlush, Deadline);
end;

end.
