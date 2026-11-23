unit OTel.Model.Service.MetricStore;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Model.Dto.Metric, OTel.Model.Dto.Telemetry;

type
  IOTelMetricStore = interface
    function RegisterInstrument(const Scope, Version, Name, UnitName, Description: string;
      Kind: TOTelMetricKind; const Bounds: array of Double): TOTelMetricDefinition;
    procedure Measure(Definition: TOTelMetricDefinition; Increment: Int64; Measurement: Double;
      const Attributes: TOTelAttributes);
  end;

  TOTelMetricSeries = class(TOTelMetricDefinition)
  public
    Points: TObjectDictionary<string, TOTelMetricPoint>;
    Overflow: TOTelMetricPoint;
    constructor Create;
    destructor Destroy; override;
  end;

  TOTelMetricStore = class(TInterfacedObject, IOTelMetricStore)
  strict private
    FInstruments: TObjectList<TOTelMetricSeries>;
    FAccepted, FRequested, FCompleted, FRejected, FWarnings, FInvalid: Int64;
    FLastTimestamp: UInt64;
    FClosing, FFailed: Boolean;
    class procedure ValidateInstrument(const Name, UnitName, Description: string;
      const Bounds: array of Double); static;
    class function SameBounds(const A, B: array of Double): Boolean; static;
    class function KeyOf(var Entries: TArray<TPair<string, Variant>>): string; static;
    class function PointFor(Series: TOTelMetricSeries; const Attributes: TOTelAttributes): TOTelMetricPoint; static;
    function Collect: TObjectList<TOTelMetricPoint>;
  public
    constructor Create;
    destructor Destroy; override;
    function RegisterInstrument(const Scope, Version, Name, UnitName, Description: string;
      Kind: TOTelMetricKind; const Bounds: array of Double): TOTelMetricDefinition;
    procedure Measure(Definition: TOTelMetricDefinition; Increment: Int64; Measurement: Double;
      const Attributes: TOTelAttributes);
    function TakeSnapshot(IntervalMs: Cardinal; var NextTick: UInt64;
      out Points: TObjectList<TOTelMetricPoint>; out Revision: Int64): Boolean;
    procedure Complete(Revision, Rejected, Warnings: Int64);
    function RequestFlush: Int64;
    function WaitFor(Target: Int64; Deadline: UInt64): Boolean;
    procedure Close;
    procedure Stop;
    function Rejected: Int64;
    function Warnings: Int64;
    function Invalid: Int64;
  end;

implementation

uses
  System.Math, System.Variants, System.Generics.Defaults, Winapi.Windows,
  OTel.Model.Dto.Configuration, OTel.Model.Service.TraceContext;

const
  InstrumentLimit = 64;
  SeriesLimit = 128;

constructor TOTelMetricSeries.Create;
begin
  inherited;
  Points := TObjectDictionary<string, TOTelMetricPoint>.Create([doOwnsValues]);
end;

destructor TOTelMetricSeries.Destroy;
begin
  Overflow.Free;
  Points.Free;
  inherited;
end;

constructor TOTelMetricStore.Create;
begin
  inherited;
  FInstruments := TObjectList<TOTelMetricSeries>.Create(True);
end;

destructor TOTelMetricStore.Destroy;
begin
  FInstruments.Free;
  inherited;
end;

class procedure TOTelMetricStore.ValidateInstrument(const Name, UnitName, Description: string;
  const Bounds: array of Double);
var
  I: Integer;
begin
  if (Name = '') or (Length(Name) > 255) or not CharInSet(Name[1], ['A'..'Z', 'a'..'z']) then
    raise EOTelConfiguration.Create('A metric name must start with a letter and have at most 255 characters.');
  for I := 2 to Length(Name) do
    if not CharInSet(Name[I], ['A'..'Z','a'..'z','0'..'9','_','-','.','/']) then
      raise EOTelConfiguration.Create('Invalid metric name.');
  if (Length(UnitName) > 63) or (Length(Description) > 1024) then
    raise EOTelConfiguration.Create('Metric unit or description exceeds the size limit.');
  if Length(Bounds) > 32 then
    raise EOTelConfiguration.Create('A histogram can have at most 32 bucket boundaries.');
  for I := Low(Bounds) to High(Bounds) do
  begin
    if IsNan(Bounds[I]) or IsInfinite(Bounds[I]) then
      raise EOTelConfiguration.Create('Histogram bucket boundaries must be finite.');
    if I > 0 then
      if Bounds[I] <= Bounds[I - 1] then
        raise EOTelConfiguration.Create('Histogram bucket boundaries must be increasing.');
  end;
end;

class function TOTelMetricStore.SameBounds(const A, B: array of Double): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := Low(A) to High(A) do
    if A[I] <> B[I] then Exit(False);
  Result := True;
end;

function TOTelMetricStore.RegisterInstrument(const Scope, Version, Name, UnitName, Description: string;
  Kind: TOTelMetricKind; const Bounds: array of Double): TOTelMetricDefinition;
var
  Series: TOTelMetricSeries;
  I: Integer;
begin
  TMonitor.Enter(Self);
  try
    if FClosing then Exit(nil);
    ValidateInstrument(Name, UnitName, Description, Bounds);
    for Series in FInstruments do
      if (Series.Scope = Scope) and (Series.Version = Version) and SameText(Series.Name, Name) then
      begin
        if (Series.Kind <> Kind) or (Series.UnitName <> UnitName) or
           (Series.Description <> Description) or not SameBounds(Series.Bounds, Bounds) then
          raise EOTelConfiguration.Create('An incompatible metric definition already exists in this scope.');
        Exit(Series);
      end;
    if FInstruments.Count >= InstrumentLimit then
      raise EOTelConfiguration.Create('The metric instrument limit has been reached.');
    Series := TOTelMetricSeries.Create;
    try
      Series.Scope := Scope;
      Series.Version := Version;
      Series.Name := Name;
      Series.UnitName := UnitName;
      Series.Description := Description;
      Series.Kind := Kind;
      SetLength(Series.Bounds, Length(Bounds));
      for I := Low(Bounds) to High(Bounds) do Series.Bounds[I] := Bounds[I];
      FInstruments.Add(Series);
    except
      Series.Free;
      raise;
    end;
    Result := Series;
  finally
    TMonitor.Exit(Self);
  end;
end;

class function TOTelMetricStore.KeyOf(var Entries: TArray<TPair<string, Variant>>): string;
var
  Entry: TPair<string, Variant>;
  Builder: TStringBuilder;
  Float: Double;
  Bits: UInt64;
  Value: string;
begin
  TArray.Sort<TPair<string, Variant>>(Entries,
    TComparer<TPair<string, Variant>>.Construct(
      function(const Left, Right: TPair<string, Variant>): Integer
      begin
        Result := CompareStr(Left.Key, Right.Key);
      end));
  Builder := TStringBuilder.Create;
  try
    for Entry in Entries do
    begin
      case VarType(Entry.Value) of
        varBoolean: Value := IntToStr(Ord(Boolean(Entry.Value)));
        varInt64, varInteger, varSmallint, varShortInt, varByte: Value := IntToStr(Int64(Entry.Value));
        varDouble, varSingle:
          begin
            Float := Entry.Value;
            if Float = 0 then Float := 0;
            Move(Float, Bits, SizeOf(Bits));
            Value := IntToHex(Bits, 16);
          end;
      else
        Value := VarToStr(Entry.Value);
      end;
      Builder.Append(Length(Entry.Key)).Append(':').Append(Entry.Key);
      Builder.Append(VarType(Entry.Value)).Append(':');
      Builder.Append(Length(Value)).Append(':').Append(Value);
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TOTelMetricStore.PointFor(Series: TOTelMetricSeries;
  const Attributes: TOTelAttributes): TOTelMetricPoint;
var
  Entries: TArray<TPair<string, Variant>>;
  Key: string;
  Overflow: Boolean;
begin
  if Assigned(Attributes) then Entries := Attributes.Entries;
  Key := KeyOf(Entries);
  if Series.Points.TryGetValue(Key, Result) then Exit;
  Overflow := Series.Points.Count >= SeriesLimit;
  if Overflow and Assigned(Series.Overflow) then Exit(Series.Overflow);
  if Overflow then
  begin
    SetLength(Entries, 0);
    SetLength(Entries, 1);
    Entries[0] := TPair<string, Variant>.Create('otel.metric.overflow', True);
  end;
  Result := TOTelMetricPoint.Create;
  try
    Result.Definition := Series;
    Result.Attributes := Entries;
    Result.Start := TOTelTraceContext.NowNanos;
    if Series.Kind = mkHistogram then SetLength(Result.Buckets, Length(Series.Bounds) + 1);
    if Overflow then Series.Overflow := Result else Series.Points.Add(Key, Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TOTelMetricStore.Measure(Definition: TOTelMetricDefinition; Increment: Int64;
  Measurement: Double; const Attributes: TOTelAttributes);
var
  Point: TOTelMetricPoint;
  Bucket: Integer;
begin
  TMonitor.Enter(Self);
  try
    if FClosing or (Definition = nil) then Exit;
    if ((Definition.Kind = mkCounter) and (Increment < 0)) or
       ((Definition.Kind = mkHistogram) and (IsNan(Measurement) or IsInfinite(Measurement) or (Measurement < 0))) then
    begin
      Inc(FInvalid);
      Exit;
    end;
    Point := PointFor(TOTelMetricSeries(Definition), Attributes);
    if Definition.Kind = mkHistogram then
    begin
      if Measurement > MaxDouble - Point.HistogramSum then
      begin
        Inc(FInvalid);
        Exit;
      end;
      Bucket := 0;
      while Bucket < Length(Definition.Bounds) do
      begin
        if Measurement <= Definition.Bounds[Bucket] then Break;
        Inc(Bucket);
      end;
      Inc(Point.Buckets[Bucket]);
      Inc(Point.Count);
      Point.HistogramSum := Point.HistogramSum + Measurement;
    end
    else
    begin
      if ((Increment > 0) and (Point.IntegerSum > High(Int64) - Increment)) or
         ((Increment < 0) and (Point.IntegerSum < Low(Int64) - Increment)) then
      begin
        Inc(FInvalid);
        Exit;
      end;
      Inc(Point.IntegerSum, Increment);
    end;
    Inc(FAccepted);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelMetricStore.Collect: TObjectList<TOTelMetricPoint>;
var
  Series: TOTelMetricSeries;
  Point: TOTelMetricPoint;
  Timestamp: UInt64;
begin
  Timestamp := TOTelTraceContext.NowNanos;
  if Timestamp <= FLastTimestamp then Timestamp := FLastTimestamp + 1;
  FLastTimestamp := Timestamp;
  Result := TObjectList<TOTelMetricPoint>.Create(True);
  try
    for Series in FInstruments do
    begin
      for Point in Series.Points.Values do Result.Add(Point.Snapshot(Timestamp));
      if Assigned(Series.Overflow) then Result.Add(Series.Overflow.Snapshot(Timestamp));
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TOTelMetricStore.TakeSnapshot(IntervalMs: Cardinal; var NextTick: UInt64;
  out Points: TObjectList<TOTelMetricPoint>; out Revision: Int64): Boolean;
var
  Tick: UInt64;
begin
  TMonitor.Enter(Self);
  try
    while True do
    begin
      Tick := GetTickCount64;
      if (FAccepted > FCompleted) and (FClosing or (FRequested > FCompleted) or (Tick >= NextTick)) then
        Break;
      if FClosing then Exit(False);
      if Tick >= NextTick then NextTick := Tick + IntervalMs;
      TMonitor.Wait(Self, Cardinal(NextTick - Tick));
    end;
    NextTick := Tick + IntervalMs;
    Revision := FAccepted;
    Points := Collect;
    Result := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelMetricStore.Complete(Revision, Rejected, Warnings: Int64);
begin
  TMonitor.Enter(Self);
  try
    FCompleted := Revision;
    Inc(FRejected, Rejected);
    Inc(FWarnings, Warnings);
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelMetricStore.RequestFlush: Int64;
begin
  TMonitor.Enter(Self);
  try
    Result := FAccepted;
    FRequested := Result;
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelMetricStore.WaitFor(Target: Int64; Deadline: UInt64): Boolean;
var
  Tick: UInt64;
begin
  TMonitor.Enter(Self);
  try
    while not FFailed and (FCompleted < Target) do
    begin
      Tick := GetTickCount64;
      if Tick >= Deadline then Exit(False);
      TMonitor.Wait(Self, Cardinal(Deadline - Tick));
    end;
    Result := not FFailed and (FRejected = 0);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelMetricStore.Close;
begin
  TMonitor.Enter(Self);
  try
    FClosing := True;
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TOTelMetricStore.Stop;
begin
  TMonitor.Enter(Self);
  try
    FFailed := (not FClosing) or (FAccepted > FCompleted);
    FClosing := True;
    TMonitor.PulseAll(Self);
  finally
    TMonitor.Exit(Self);
  end;
end;

function TOTelMetricStore.Rejected: Int64;
begin
  TMonitor.Enter(Self);
  try Result := FRejected; finally TMonitor.Exit(Self); end;
end;

function TOTelMetricStore.Warnings: Int64;
begin
  TMonitor.Enter(Self);
  try Result := FWarnings; finally TMonitor.Exit(Self); end;
end;

function TOTelMetricStore.Invalid: Int64;
begin
  TMonitor.Enter(Self);
  try Result := FInvalid; finally TMonitor.Exit(Self); end;
end;

end.
