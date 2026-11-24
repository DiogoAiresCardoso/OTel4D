unit OTel.Domain.TraceHeaders;

interface

type
  IOTelTraceHeaders = interface
    function ValidParent(const Value: string): Boolean;
    function ValidState(const Value: string): string;
  end;

  TOTelTraceHeaders = class(TInterfacedObject, IOTelTraceHeaders)
  strict private
    function IsHex(const Text: string; Nonzero: Boolean): Boolean;
    function ValidParent(const Value: string): Boolean;
    function ValidState(const Value: string): string;
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.RegularExpressions;

function TOTelTraceHeaders.IsHex(const Text: string; Nonzero: Boolean): Boolean;
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

function TOTelTraceHeaders.ValidParent(const Value: string): Boolean;
begin
  Result := False;
  if (Length(Value) < 55) or (Length(Value) > 512) then Exit;
  if (Value[3] <> '-') or (Value[36] <> '-') or (Value[53] <> '-') then Exit;
  if (Copy(Value, 1, 2) = 'ff') or not IsHex(Copy(Value, 1, 2), False) then Exit;
  if (Length(Value) > 55) and ((Copy(Value, 1, 2) = '00') or (Value[56] <> '-')) then Exit;
  Result := IsHex(Copy(Value, 4, 32), True) and IsHex(Copy(Value, 37, 16), True)
    and IsHex(Copy(Value, 54, 2), False);
end;

function TOTelTraceHeaders.ValidState(const Value: string): string;
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

end.
