unit OTel.Controller.Trace;

interface

uses
  System.SysUtils, System.Diagnostics, OTel.Model.Dto.Span;

type
  TOTelSpan = class
  strict private
    FSink: IOTelSpanSink;
    FData: TOTelSpanData;
    FTraceParent, FTraceState: string;
    FDuration: TStopwatch;
    procedure SetValue(const Key: string; const Value: Variant);
    procedure AppendEvent(const Name, ErrorType, ErrorMessage: string);
  public
    constructor Create(const Sink: IOTelSpanSink; const Scope, Version, Name, Parent, State: string;
      Kind: TOTelSpanKind; Remote: Boolean);
    destructor Destroy; override;
    procedure SetAttribute(const Key, Value: string); overload;
    procedure SetAttribute(const Key: string; Value: Int64); overload;
    procedure SetAttribute(const Key: string; Value: Boolean); overload;
    procedure SetAttribute(const Key: string; Value: Double); overload;
    procedure AddEvent(const Name: string);
    procedure RecordException(const Error: Exception; IncludeMessage: Boolean = False);
    procedure SetStatus(Value: TOTelStatus; const Description: string = '');
    procedure WithContext(const Action: TProc);
    function IsRecording: Boolean;
    procedure Finish;
    property TraceParent: string read FTraceParent;
    property TraceState: string read FTraceState;
  end;

  TOTelTracer = class
  strict private
    FSink: IOTelSpanSink;
    FName, FVersion: string;
  public
    constructor Create(const Sink: IOTelSpanSink; const Name, Version: string);
    // Each call returns a caller-owned span. Explicit parent headers come from a remote carrier.
    function StartSpan(const Name: string; Kind: TOTelSpanKind = skInternal): TOTelSpan; overload;
    function StartSpan(const Name: string; Kind: TOTelSpanKind;
      const TraceParent: string; const TraceState: string = ''): TOTelSpan; overload;
  end;

implementation

uses
  OTel.Model.Service.TraceContext;

constructor TOTelTracer.Create(const Sink: IOTelSpanSink; const Name, Version: string);
begin
  inherited Create;
  FSink := Sink;
  FName := Copy(Name, 1, 256);
  if FName = '' then FName := 'OTel4D';
  FVersion := Copy(Version, 1, 128);
end;

function TOTelTracer.StartSpan(const Name: string; Kind: TOTelSpanKind): TOTelSpan;
begin
  Result := TOTelSpan.Create(FSink, FName, FVersion, Name, TOTelTraceContext.CurrentParent,
    TOTelTraceContext.CurrentState, Kind, False);
end;

function TOTelTracer.StartSpan(const Name: string; Kind: TOTelSpanKind;
  const TraceParent, TraceState: string): TOTelSpan;
begin
  if not TOTelTraceContext.ValidParent(TraceParent) then Exit(StartSpan(Name, Kind));
  Result := TOTelSpan.Create(FSink, FName, FVersion, Name, TraceParent, TraceState, Kind, True);
end;

constructor TOTelSpan.Create(const Sink: IOTelSpanSink; const Scope, Version, Name, Parent, State: string;
  Kind: TOTelSpanKind; Remote: Boolean);
var
  TraceId, SpanId, ParentId: string;
  Flags: Cardinal;
  Data: TOTelSpanData;
begin
  inherited Create;
  FSink := Sink;
  if not Assigned(Sink) or not Sink.IsAccepting then
  begin
    if TOTelTraceContext.ValidParent(Parent) then
    begin
      FTraceParent := Parent;
      FTraceState := TOTelTraceContext.ValidState(State);
    end;
    Exit;
  end;
  if TOTelTraceContext.ValidParent(Parent) then
  begin
    TraceId := Copy(Parent, 4, 32);
    ParentId := Copy(Parent, 37, 16);
    Flags := StrToInt('$' + Copy(Parent, 54, 2));
    FTraceState := TOTelTraceContext.ValidState(State);
  end
  else
  begin
    TraceId := TOTelTraceContext.NewId(16);
    Flags := 1;
  end;
  SpanId := TOTelTraceContext.NewId(8);
  FTraceParent := '00-' + TraceId + '-' + SpanId + '-' + LowerCase(IntToHex(Flags, 2));
  if (Flags and 1) = 0 then Exit;

  Data := TOTelSpanData.Create;
  try
    Data.TraceId := TraceId;
    Data.SpanId := SpanId;
    Data.ParentId := ParentId;
    Data.TraceState := FTraceState;
    Data.Flags := Flags;
    if ParentId <> '' then
    begin
      Data.Flags := Flags or $100;
      if Remote then Data.Flags := Data.Flags or $200;
    end;
    Data.Name := Copy(Name, 1, 256);
    if Data.Name = '' then Data.Name := 'unnamed';
    Data.ScopeName := Scope;
    Data.ScopeVersion := Version;
    Data.Kind := Kind;
    Data.StartNanos := TOTelTraceContext.NowNanos;
    FDuration := TStopwatch.StartNew;
    FData := Data;
  except
    Data.Free;
    raise;
  end;
end;

destructor TOTelSpan.Destroy;
begin
  Finish;
  inherited;
end;

function TOTelSpan.IsRecording: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := Assigned(FData);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelSpan.SetValue(const Key: string; const Value: Variant);
begin
  TMonitor.Enter(Self);
  try
    if FData = nil then Exit;
    if (Key = '') or (Length(Key) > 256) or
       ((FData.Attributes.Count >= 32) and not FData.Attributes.ContainsKey(Key)) then
      Inc(FData.DroppedAttributes)
    else
      FData.Attributes.AddOrSetValue(Key, Value);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelSpan.SetAttribute(const Key, Value: string);
begin
  SetValue(Key, Copy(Value, 1, 1024));
end;

procedure TOTelSpan.SetAttribute(const Key: string; Value: Int64);
begin
  SetValue(Key, Value);
end;

procedure TOTelSpan.SetAttribute(const Key: string; Value: Boolean);
begin
  SetValue(Key, Value);
end;

procedure TOTelSpan.SetAttribute(const Key: string; Value: Double);
begin
  SetValue(Key, Value);
end;

procedure TOTelSpan.AppendEvent(const Name, ErrorType, ErrorMessage: string);
var
  Event: TOTelEvent;
begin
  TMonitor.Enter(Self);
  try
    if FData = nil then Exit;
    if FData.Events.Count >= 32 then
    begin
      Inc(FData.DroppedEvents);
      Exit;
    end;
    Event := TOTelEvent.Create;
    FData.Events.Add(Event);
    Event.TimeNanos := TOTelTraceContext.NowNanos;
    Event.Name := Copy(Name, 1, 256);
    Event.ExceptionType := Copy(ErrorType, 1, 256);
    Event.ExceptionMessage := Copy(ErrorMessage, 1, 1024);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelSpan.AddEvent(const Name: string);
begin
  if Name <> '' then AppendEvent(Name, '', '');
end;

procedure TOTelSpan.RecordException(const Error: Exception; IncludeMessage: Boolean);
begin
  if Error = nil then Exit;
  if IncludeMessage then AppendEvent('exception', Error.ClassName, Error.Message)
  else AppendEvent('exception', Error.ClassName, '');
end;

procedure TOTelSpan.SetStatus(Value: TOTelStatus; const Description: string);
begin
  TMonitor.Enter(Self);
  try
    if (FData = nil) or (Value = ssUnset) then Exit;
    if FData.Status = ssOk then Exit;
    FData.Status := Value;
    if Value = ssError then FData.StatusMessage := Copy(Description, 1, 1024)
    else FData.StatusMessage := '';
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelSpan.WithContext(const Action: TProc);
begin
  TOTelTraceContext.WithContext(FTraceParent, FTraceState, Action);
end;

procedure TOTelSpan.Finish;
var
  Data: TOTelSpanData;
  Elapsed, Frequency: Int64;
begin
  TMonitor.Enter(Self);
  try
    Data := FData;
    if Data = nil then Exit;
    Elapsed := FDuration.ElapsedTicks;
    Frequency := TStopwatch.Frequency;
    Data.EndNanos := Data.StartNanos + UInt64((Elapsed div Frequency) * 1000000000
      + (Elapsed mod Frequency) * 1000000000 div Frequency);
    FData := nil;
    FSink.Submit(Data);
  finally
    TMonitor.Exit(Self);
  end;
end;

end.
