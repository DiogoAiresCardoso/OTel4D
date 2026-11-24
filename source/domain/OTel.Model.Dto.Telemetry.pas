unit OTel.Model.Dto.Telemetry;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  IOTelSink<T: class> = interface
    function IsAccepting: Boolean;
    // Takes ownership even when the sink declines the item.
    procedure Submit(Data: T);
  end;

  TOTelAttributes = class
  strict private
    FItems: TDictionary<string, Variant>;
    FDropped: Cardinal;
    procedure Store(const Key: string; const Value: Variant);
    class function LimitText(const Value: string; Limit: Integer): string; static;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Put(const Key, Value: string); overload;
    procedure Put(const Key: string; Value: Int64); overload;
    procedure Put(const Key: string; Value: Boolean); overload;
    procedure Put(const Key: string; Value: Double); overload;
    function Snapshot: TOTelAttributes;
    function Entries: TArray<TPair<string, Variant>>;
    property Dropped: Cardinal read FDropped;
  end;

implementation

constructor TOTelAttributes.Create;
begin
  inherited;
  FItems := TDictionary<string, Variant>.Create;
end;

destructor TOTelAttributes.Destroy;
begin
  FItems.Free;
  inherited;
end;

class function TOTelAttributes.LimitText(const Value: string; Limit: Integer): string;
begin
  Result := Copy(Value, 1, Limit);
  if (Length(Value) > Limit) and (Result[Limit] >= #$D800) and (Result[Limit] <= #$DBFF) then
    SetLength(Result, Limit - 1);
end;

procedure TOTelAttributes.Store(const Key: string; const Value: Variant);
begin
  if (Key = '') or (Length(Key) > 128) or (Key = 'otel.metric.overflow') or
     ((FItems.Count = 16) and not FItems.ContainsKey(Key)) then
    Inc(FDropped)
  else
    FItems.AddOrSetValue(Key, Value);
end;

procedure TOTelAttributes.Put(const Key, Value: string);
begin
  Store(Key, LimitText(Value, 256));
end;

procedure TOTelAttributes.Put(const Key: string; Value: Int64);
begin
  Store(Key, Value);
end;

procedure TOTelAttributes.Put(const Key: string; Value: Boolean);
begin
  Store(Key, Value);
end;

procedure TOTelAttributes.Put(const Key: string; Value: Double);
begin
  Store(Key, Value);
end;

function TOTelAttributes.Snapshot: TOTelAttributes;
var
  Pair: TPair<string, Variant>;
begin
  Result := TOTelAttributes.Create;
  try
    Result.FDropped := FDropped;
    for Pair in FItems do Result.FItems.Add(Pair.Key, Pair.Value);
  except
    Result.Free;
    raise;
  end;
end;

function TOTelAttributes.Entries: TArray<TPair<string, Variant>>;
begin
  Result := FItems.ToArray;
end;

end.
