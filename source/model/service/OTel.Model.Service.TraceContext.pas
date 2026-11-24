unit OTel.Model.Service.TraceContext;

interface

uses
  System.SysUtils;

type
  TOTelTraceContext = class
  strict private
    FTraceParent, FTraceState: string;
    class function IsHex(const Text: string; Nonzero: Boolean): Boolean; static;
  public
    class function ValidParent(const Value: string): Boolean; static;
    class function ValidState(const Value: string): string; static;
    class function NewId(Bytes: Integer): string; static;
    class function NowNanos: UInt64; static;
    class function CurrentParent: string; static;
    class function CurrentState: string; static;
    class procedure WithContext(const Parent, State: string; const Action: TProc); static;
  end;

implementation

uses
  Winapi.Windows, System.Generics.Collections, System.RegularExpressions;

threadvar
  Current: TOTelTraceContext;

class function TOTelTraceContext.IsHex(const Text: string; Nonzero: Boolean): Boolean;
var
  Ch: Char;
  AnyNonzero: Boolean;
begin
  AnyNonzero := False;
  for Ch in Text do
  begin
    if not CharInSet(Ch, ['0'..'9', 'a'..'f']) then Exit(False);
    AnyNonzero := AnyNonzero or (Ch <> '0');
  end;
  Result := (Text <> '') and (AnyNonzero or not Nonzero);
end;

class function TOTelTraceContext.ValidParent(const Value: string): Boolean;
begin
  Result := False;
  if (Length(Value) < 55) or (Length(Value) > 512) then Exit;
  if (Value[3] <> '-') or (Value[36] <> '-') or (Value[53] <> '-') then Exit;
  if (Copy(Value, 1, 2) = 'ff') or not IsHex(Copy(Value, 1, 2), False) then Exit;
  if (Length(Value) > 55) and ((Copy(Value, 1, 2) = '00') or (Value[56] <> '-')) then Exit;
  Result := IsHex(Copy(Value, 4, 32), True) and IsHex(Copy(Value, 37, 16), True)
    and IsHex(Copy(Value, 54, 2), False);
end;

class function TOTelTraceContext.ValidState(const Value: string): string;
const
  KeyPattern = '\A(?:[a-z][a-z0-9_*/-]{0,255}|[a-z0-9][a-z0-9_*/-]{0,240}@[a-z][a-z0-9_*/-]{0,13})\z';
var
  Members: TArray<string>;
  Member, Key, Item: string;
  Keys: TList<string>;
  I, EqualsAt: Integer;
  Ch: Char;
begin
  Result := '';
  if (Value = '') or (Length(Value) > 512) then Exit;
  for Ch in Value do
    if ((Ord(Ch) < 32) and (Ch <> #9)) or (Ord(Ch) > 126) then Exit;
  Members := Value.Split([',']);
  Keys := TList<string>.Create;
  try
    for I := 0 to High(Members) do
    begin
      Member := Trim(Members[I]);
      if Member = '' then Continue;
      EqualsAt := Pos('=', Member);
      if EqualsAt < 2 then Exit;
      Key := Copy(Member, 1, EqualsAt - 1);
      Item := Copy(Member, EqualsAt + 1, MaxInt);
      if (Keys.Count >= 32) or Keys.Contains(Key) or not TRegEx.IsMatch(Key, KeyPattern) then Exit;
      if (Item = '') or (Length(Item) > 256) then Exit;
      for Ch in Item do
        if (Ord(Ch) < 32) or (Ch = '=') then Exit;
      Keys.Add(Key);
    end;
    if Keys.Count > 0 then Result := Value;
  finally
    Keys.Free;
  end;
end;

class function TOTelTraceContext.NewId(Bytes: Integer): string;
var
  Id: TGUID;
  Hex: string;
begin
  if CreateGUID(Id) <> 0 then
    raise EInvalidOpException.Create('Cannot generate a span identifier.');
  Hex := LowerCase(GUIDToString(Id));
  Hex := StringReplace(Copy(Hex, 2, 36), '-', '', [rfReplaceAll]);
  Result := Copy(Hex, Length(Hex) - Bytes * 2 + 1, Bytes * 2);
end;

class function TOTelTraceContext.NowNanos: UInt64;
const
  UnixEpochTicks: UInt64 = 116444736000000000;
var
  Time: TFileTime;
begin
  GetSystemTimeAsFileTime(Time);
  Result := (((UInt64(Time.dwHighDateTime) shl 32) or Time.dwLowDateTime) - UnixEpochTicks) * 100;
end;

class function TOTelTraceContext.CurrentParent: string;
begin
  if Assigned(Current) then Result := Current.FTraceParent else Result := '';
end;

class function TOTelTraceContext.CurrentState: string;
begin
  if Assigned(Current) then Result := Current.FTraceState else Result := '';
end;

class procedure TOTelTraceContext.WithContext(const Parent, State: string; const Action: TProc);
var
  Previous, Scope: TOTelTraceContext;
begin
  if not Assigned(Action) then raise EArgumentNilException.Create('Action must be assigned.');
  if not ValidParent(Parent) then
  begin
    Action();
    Exit;
  end;
  Scope := TOTelTraceContext.Create;
  try
    Scope.FTraceParent := Parent;
    Scope.FTraceState := ValidState(State);
    Previous := Current;
    Current := Scope;
    try
      Action();
    finally
      Current := Previous;
    end;
  finally
    Scope.Free;
  end;
end;

end.
