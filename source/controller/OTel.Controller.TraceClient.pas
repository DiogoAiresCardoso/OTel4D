unit OTel.Controller.TraceClient;

interface

uses
  System.Classes, System.SyncObjs, OTel.Model.Dto.Configuration, OTel.Model.Dto.Span,
  OTel.Controller.Trace, OTel.Controller.SpanQueue, OTel.Transport.Http;

type
  TOTelTraceClient = class
  strict private
    FQueue: TOTelSpanQueue;
    FSink: IOTelSpanSink;
    FWorker: TThread;
    FAbort: TEvent;
    FTransport: TOTelHttpTransport;
  public
    constructor Create(const Config: TOTelConfiguration);
    destructor Destroy; override;
    function GetTracer(const ScopeName: string; const ScopeVersion: string = ''): TOTelTracer;
    function ForceFlush(TimeoutMs: Cardinal = 10000): Boolean;
    function Shutdown(TimeoutMs: Cardinal = 10000): Boolean;
    function DroppedSpans: Int64;
    function RejectedSpans: Int64;
    function DeliveryWarnings: Int64;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, Winapi.Windows, OTel.View.TraceProtobuf;

type
  TDeliveryWorker = class(TThread)
  strict private
    FQueue: TOTelSpanQueue;
    FTransport: TOTelHttpTransport;
    FService: string;
  protected
    procedure Execute; override;
  private
    function Deliver(Batch: TObjectList<TOTelSpanData>; out Warning: Boolean): Integer;
  public
    constructor Create(Queue: TOTelSpanQueue; Transport: TOTelHttpTransport; const Service: string);
  end;

constructor TDeliveryWorker.Create(Queue: TOTelSpanQueue; Transport: TOTelHttpTransport; const Service: string);
begin
  inherited Create(True);
  FQueue := Queue;
  FTransport := Transport;
  FService := Service;
end;

function TDeliveryWorker.Deliver(Batch: TObjectList<TOTelSpanData>; out Warning: Boolean): Integer;
begin
  try
    Result := FTransport.Send(TOTelTraceProtobuf.Encode(FService, Batch), Batch.Count, Warning);
  except
    // Operational failures are reported to the host as undelivered spans.
    on E: Exception do
    begin
      Warning := False;
      Result := Batch.Count;
    end;
  end;
end;

procedure TDeliveryWorker.Execute;
var
  Batch: TObjectList<TOTelSpanData>;
  Rejected: Integer;
  Warning: Boolean;
begin
  if Terminated then Exit;
  try
    Batch := TObjectList<TOTelSpanData>.Create(True);
    try
      while FQueue.TakeBatch(Batch) do
      begin
        Rejected := Deliver(Batch, Warning);
        FQueue.Complete(Batch.Count, Rejected, Warning);
        Batch.Clear;
      end;
    finally
      Batch.Free;
    end;
  finally
    FQueue.Abandon;
  end;
end;

constructor TOTelTraceClient.Create(const Config: TOTelConfiguration);
begin
  inherited Create;
  if Config = nil then raise EArgumentNilException.Create('Config must be assigned.');
  FQueue := TOTelSpanQueue.Create(Config.SdkDisabled);
  FSink := FQueue;
  if Config.SdkDisabled then Exit;
  FAbort := TEvent.Create(nil, True, False, '');
  FTransport := TOTelHttpTransport.Create(Config.TracesEndpoint, Config.TraceHeaders, FAbort, Config.TraceTimeoutMs);
  FWorker := TDeliveryWorker.Create(FQueue, FTransport, Config.ServiceName);
  FWorker.Start;
end;

destructor TOTelTraceClient.Destroy;
begin
  if Assigned(FQueue) then FQueue.Close;
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

function TOTelTraceClient.GetTracer(const ScopeName, ScopeVersion: string): TOTelTracer;
begin
  Result := TOTelTracer.Create(FSink, ScopeName, ScopeVersion);
end;

function TOTelTraceClient.ForceFlush(TimeoutMs: Cardinal): Boolean;
begin
  Result := FQueue.Flush(TimeoutMs);
end;

function TOTelTraceClient.Shutdown(TimeoutMs: Cardinal): Boolean;
begin
  FQueue.Close;
  Result := not Assigned(FWorker) or (WaitForSingleObject(FWorker.Handle, TimeoutMs) = WAIT_OBJECT_0);
  if Result then Result := FQueue.Flush(0);
end;

function TOTelTraceClient.DroppedSpans: Int64;
begin
  Result := FQueue.Dropped;
end;

function TOTelTraceClient.RejectedSpans: Int64;
begin
  Result := FQueue.Rejected;
end;

function TOTelTraceClient.DeliveryWarnings: Int64;
begin
  Result := FQueue.Warnings;
end;

end.
