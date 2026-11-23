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
  System.SysUtils, System.Math, System.Generics.Collections, Winapi.Windows,
  OTel.Model.Dto.Metric, OTel.View.MetricProtobuf;

type
  TMetricWorker = class(TThread)
  strict private
    FStore: TOTelMetricStore;
    FTransport: TOTelHttpTransport;
    FInterval: Cardinal;
    FService: string;
    procedure Deliver(Points: TObjectList<TOTelMetricPoint>; Revision: Int64);
  protected
    procedure Execute; override;
  public
    constructor Create(Store: TOTelMetricStore; Transport: TOTelHttpTransport;
      IntervalMs: Integer; const Service: string);
  end;

constructor TMetricWorker.Create(Store: TOTelMetricStore; Transport: TOTelHttpTransport;
  IntervalMs: Integer; const Service: string);
begin
  inherited Create(True);
  FStore := Store;
  FTransport := Transport;
  FInterval := IntervalMs;
  FService := Service;
end;

procedure TMetricWorker.Deliver(Points: TObjectList<TOTelMetricPoint>; Revision: Int64);
const
  PointBatchSize = 128;
var
  Offset, Count, Rejected, Warnings: Integer;
  Warning: Boolean;
begin
  Rejected := 0;
  Warnings := 0;
  Offset := 0;
  while Offset < Points.Count do
  begin
    Count := Min(Points.Count - Offset, PointBatchSize);
    try
      Inc(Rejected, FTransport.Send(TOTelMetricProtobuf.Encode(FService, Points, Offset, Count), Count, Warning));
      if Warning then Inc(Warnings);
    except
      on E: Exception do Inc(Rejected, Count);
    end;
    Inc(Offset, Count);
  end;
  FStore.Complete(Revision, Rejected, Warnings);
end;

procedure TMetricWorker.Execute;
var
  Points: TObjectList<TOTelMetricPoint>;
  NextTick: UInt64;
  Revision: Int64;
begin
  if Terminated then Exit;
  NextTick := GetTickCount64 + FInterval;
  try
    while FStore.TakeSnapshot(FInterval, NextTick, Points, Revision) do
    try
      Deliver(Points, Revision);
    finally
      Points.Free;
    end;
  finally
    FStore.Stop;
  end;
end;

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
