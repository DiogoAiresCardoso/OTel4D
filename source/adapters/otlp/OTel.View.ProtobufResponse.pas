unit OTel.View.ProtobufResponse;

interface

uses
  System.SysUtils;

type
  IOTelResponseDecoder = interface
    function Decode(const Bytes: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
  end;

  TOTelProtobufResponse = class(TInterfacedObject, IOTelResponseDecoder)
  strict private
    FBody: TBytes;
    FPos: Integer;
    function Varint(Limit: Integer; out Value: UInt64): Boolean;
    function Skip(Wire, Limit: Integer): Boolean;
    function Fields(Limit: Integer; Partial: Boolean; var Rejected: UInt64; var Warning: Boolean): Boolean;
  public
    function Decode(const Bytes: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
  end;

implementation

function TOTelProtobufResponse.Varint(Limit: Integer; out Value: UInt64): Boolean;
var
  B, Shift: Integer;
begin
  Value := 0;
  Shift := 0;
  while (FPos < Limit) and (Shift <= 63) do
  begin
    B := FBody[FPos];
    Inc(FPos);
    if (Shift = 63) and (B > 1) then Exit(False);
    Value := Value or (UInt64(B and 127) shl Shift);
    if B < 128 then Exit(True);
    Inc(Shift, 7);
  end;
  Result := False;
end;

function TOTelProtobufResponse.Skip(Wire, Limit: Integer): Boolean;
var
  N: UInt64;
begin
  case Wire of
    0: Exit(Varint(Limit, N));
    1: N := 8;
    2: if not Varint(Limit, N) then Exit(False);
    5: N := 4;
  else
    Exit(False);
  end;
  Result := N <= UInt64(Limit - FPos);
  if Result then Inc(FPos, Integer(N));
end;

function TOTelProtobufResponse.Fields(Limit: Integer; Partial: Boolean; var Rejected: UInt64; var Warning: Boolean): Boolean;
var
  Tag, N: UInt64;
begin
  while FPos < Limit do
  begin
    if not Varint(Limit, Tag) or (Tag < 8) or (Tag > High(Cardinal)) then Exit(False);
    if not Partial and (Tag = 10) then
    begin
      if not Varint(Limit, N) or (N > UInt64(Limit - FPos)) then Exit(False);
      if not Fields(FPos + Integer(N), True, Rejected, Warning) then Exit(False);
    end
    else if Partial and (Tag = 8) then
    begin
      if not Varint(Limit, Rejected) or (Rejected > UInt64(High(Int64))) then Exit(False);
    end
    else if Partial and (Tag = 18) then
    begin
      if not Varint(Limit, N) or (N > UInt64(Limit - FPos)) then Exit(False);
      Warning := N <> 0;
      Inc(FPos, Integer(N));
    end
    else if not Skip(Tag and 7, Limit) then Exit(False);
  end;
  Result := True;
end;

function TOTelProtobufResponse.Decode(const Bytes: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
begin
  FBody := Bytes;
  FPos := 0;
  Rejected := 0;
  Warning := False;
  try
    Result := Fields(Length(Bytes), False, Rejected, Warning);
  finally
    FBody := nil;
  end;
end;

end.
