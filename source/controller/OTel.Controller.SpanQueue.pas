unit OTel.Controller.SpanQueue;

interface

uses
  Winapi.Windows, System.Generics.Collections, OTel.Model.Dto.Telemetry, OTel.Model.Dto.Span;

type
  TOTelBatchQueue<T: class> = class(TInterfacedObject, IOTelSink<T>)
  strict private
    FItems: TQueue<T>;
    FClosing, FDisabled: Boolean;
    FFirstQueued: UInt64;
    FAccepted, FCompleted, FFlushTarget, FDropped, FRejected, FWarnings: Int64;
  public
    constructor Create(Disabled: Boolean);
    destructor Destroy; override;
    function IsAccepting: Boolean;
    procedure Submit(Data: T);
    function TakeBatch(Batch: TObjectList<T>): Boolean;
    procedure Complete(Count, Rejected: Integer; Warning: Boolean);
    function RequestFlush: Int64;
    function WaitFor(Target: Int64; Deadline: UInt64): Boolean;
    procedure Close;
    procedure Abandon;
    function Dropped: Int64;
    function Rejected: Int64;
    function Warnings: Int64;
  end;

  TOTelSpanQueue = TOTelBatchQueue<TOTelSpanData>;

implementation

const
  QueueLimit = 2048;
  BatchLimit = 128;
  ScheduleDelayMs = 1000;

constructor TOTelBatchQueue<T>.Create(Disabled: Boolean);
begin
  inherited Create;
  FItems := TQueue<T>.Create;
  FDisabled := Disabled;
end;

destructor TOTelBatchQueue<T>.Destroy;
begin
  if Assigned(FItems) then
    while FItems.Count > 0 do FItems.Dequeue.Free;
  FItems.Free;
  inherited;
end;

function TOTelBatchQueue<T>.IsAccepting: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := not FClosing and not FDisabled;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelBatchQueue<T>.Submit(Data: T);
begin
  TMonitor.Enter(Self);
  try
    if FClosing or FDisabled or (FItems.Count >= QueueLimit) then
    begin
      Inc(FDropped);
      Exit;
    end;
    FItems.Enqueue(Data);
    Data := nil;
    Inc(FAccepted);
    if FItems.Count = 1 then FFirstQueued := GetTickCount64;
    if (FItems.Count = 1) or (FItems.Count = BatchLimit) then TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
    Data.Free;
  end;
end;

function TOTelBatchQueue<T>.TakeBatch(Batch: TObjectList<T>): Boolean;
var
  Elapsed: UInt64;
begin
  TMonitor.Enter(Self);
  try
    while True do
    begin
      if FItems.Count = 0 then
      begin
        if FClosing then Exit(False);
        TMonitor.Wait(Self, INFINITE);
      end
      else
      begin
        Elapsed := GetTickCount64 - FFirstQueued;
        if FClosing or (FFlushTarget > FCompleted) or (FItems.Count >= BatchLimit)
          or (Elapsed >= ScheduleDelayMs) then Break;
        TMonitor.Wait(Self, Cardinal(ScheduleDelayMs - Elapsed));
      end;
    end;
    while (Batch.Count < BatchLimit) and (FItems.Count > 0) do
      Batch.Add(FItems.Dequeue);
    Result := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelBatchQueue<T>.Complete(Count, Rejected: Integer; Warning: Boolean);
begin
  TMonitor.Enter(Self);
  try
    Inc(FCompleted, Count);
    Inc(FRejected, Rejected);
    if Warning then Inc(FWarnings);
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelBatchQueue<T>.RequestFlush: Int64;
begin
  TMonitor.Enter(Self);
  try
    Result := FAccepted;
    FFlushTarget := Result;
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelBatchQueue<T>.WaitFor(Target: Int64; Deadline: UInt64): Boolean;
var
  NowTick: UInt64;
begin
  TMonitor.Enter(Self);
  try
    while FCompleted < Target do
    begin
      NowTick := GetTickCount64;
      if NowTick >= Deadline then Exit(False);
      TMonitor.Wait(Self, Cardinal(Deadline - NowTick));
    end;
    Result := (FRejected = 0) and (FDropped = 0);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelBatchQueue<T>.Close;
begin
  TMonitor.Enter(Self);
  try
    FClosing := True;
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelBatchQueue<T>.Abandon;
var
  Count: Integer;
begin
  TMonitor.Enter(Self);
  try
    FClosing := True;
    Count := FItems.Count;
    while FItems.Count <> 0 do FItems.Dequeue.Free;
    Inc(FCompleted, Count);
    Inc(FRejected, Count);
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelBatchQueue<T>.Dropped: Int64;
begin
  TMonitor.Enter(Self);
  try Result := FDropped; finally TMonitor.Exit(Self); end;
end;

function TOTelBatchQueue<T>.Rejected: Int64;
begin
  TMonitor.Enter(Self);
  try Result := FRejected; finally TMonitor.Exit(Self); end;
end;

function TOTelBatchQueue<T>.Warnings: Int64;
begin
  TMonitor.Enter(Self);
  try Result := FWarnings; finally TMonitor.Exit(Self); end;
end;

end.
