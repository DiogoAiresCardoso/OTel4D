unit OTel.View.Protobuf;

interface

uses
  System.Classes, System.SysUtils;

type
  TProtoWriter = class(TMemoryStream)
  strict private
    procedure Varint(Value: UInt64);
    procedure Tag(Field, Wire: Integer);
  public
    procedure Number(Field: Integer; Value: UInt64);
    procedure Fixed32(Field: Integer; Value: Cardinal);
    procedure Fixed64(Field: Integer; Value: UInt64);
    procedure Bytes(Field: Integer; const Value: TBytes);
    procedure Text(Field: Integer; const Value: string);
    procedure Id(Field: Integer; const Hex: string);
    procedure MessageField(Field: Integer; Value: TProtoWriter);
    procedure Attribute(Field: Integer; const Key: string; const Value: Variant);
    function Buffer: TBytes;
  end;

  TOTelProtobufResponse = class
  public
    class function Decode(const Body: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean; static;
  end;

implementation

uses
  System.Variants;

procedure TProtoWriter.Varint(Value: UInt64);
var
  B: Byte;
begin
  while Value >= 128 do
  begin
    B := Byte(Value and 127) or 128;
    WriteBuffer(B, 1);
    Value := Value shr 7;
  end;
  B := Byte(Value);
  WriteBuffer(B, 1);
end;

procedure TProtoWriter.Tag(Field, Wire: Integer);
begin
  Varint(UInt64(Field shl 3 or Wire));
end;

procedure TProtoWriter.Number(Field: Integer; Value: UInt64);
begin
  Tag(Field, 0);
  Varint(Value);
end;

procedure TProtoWriter.Fixed32(Field: Integer; Value: Cardinal);
begin
  Tag(Field, 5);
  WriteBuffer(Value, SizeOf(Value));
end;

procedure TProtoWriter.Fixed64(Field: Integer; Value: UInt64);
begin
  Tag(Field, 1);
  WriteBuffer(Value, SizeOf(Value));
end;

procedure TProtoWriter.Bytes(Field: Integer; const Value: TBytes);
begin
  Tag(Field, 2);
  Varint(Length(Value));
  if Length(Value) > 0 then WriteBuffer(Value[0], Length(Value));
end;

procedure TProtoWriter.Text(Field: Integer; const Value: string);
begin
  Bytes(Field, TEncoding.UTF8.GetBytes(Value));
end;

procedure TProtoWriter.Id(Field: Integer; const Hex: string);
var
  Raw: TBytes;
begin
  if Hex = '' then Exit;
  SetLength(Raw, Length(Hex) div 2);
  HexToBin(PChar(Hex), @Raw[0], Length(Raw));
  Bytes(Field, Raw);
end;

procedure TProtoWriter.MessageField(Field: Integer; Value: TProtoWriter);
begin
  Tag(Field, 2);
  Varint(Value.Size);
  if Value.Size > 0 then WriteBuffer(Value.Memory^, Value.Size);
end;

function TProtoWriter.Buffer: TBytes;
begin
  SetLength(Result, Size);
  if Size > 0 then Move(Memory^, Result[0], Size);
end;

procedure TProtoWriter.Attribute(Field: Integer; const Key: string; const Value: Variant);
var
  Pair, Any: TProtoWriter;
  FloatValue: Double;
  Bits: UInt64;
begin
  Pair := TProtoWriter.Create;
  try
    Any := TProtoWriter.Create;
    try
      case VarType(Value) of
        varBoolean: Any.Number(2, Ord(Boolean(Value)));
        varInt64, varInteger, varSmallint, varShortInt, varByte: Any.Number(3, UInt64(Int64(Value)));
        varDouble, varSingle:
          begin
            FloatValue := Value;
            Move(FloatValue, Bits, SizeOf(Bits));
            Any.Fixed64(4, Bits);
          end;
      else
        Any.Text(1, VarToStr(Value));
      end;
      Pair.Text(1, Key);
      Pair.MessageField(2, Any);
      MessageField(Field, Pair);
    finally
      Any.Free;
    end;
  finally
    Pair.Free;
  end;
end;

type
  TProtoReader = class
  strict private
    FBody: TBytes;
    FPos: Integer;
    function Varint(Limit: Integer; out Value: UInt64): Boolean;
    function Skip(Wire, Limit: Integer): Boolean;
  public
    function Parse(const Bytes: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
    function Fields(Limit: Integer; Partial: Boolean; var Rejected: UInt64; var Warning: Boolean): Boolean;
  end;

function TProtoReader.Varint(Limit: Integer; out Value: UInt64): Boolean;
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

function TProtoReader.Skip(Wire, Limit: Integer): Boolean;
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

function TProtoReader.Fields(Limit: Integer; Partial: Boolean; var Rejected: UInt64; var Warning: Boolean): Boolean;
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

function TProtoReader.Parse(const Bytes: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
begin
  FBody := Bytes;
  FPos := 0;
  Rejected := 0;
  Warning := False;
  Result := Fields(Length(Bytes), False, Rejected, Warning);
end;

class function TOTelProtobufResponse.Decode(const Body: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
var
  Reader: TProtoReader;
begin
  Reader := TProtoReader.Create;
  try
    Result := Reader.Parse(Body, Rejected, Warning);
  finally
    Reader.Free;
  end;
end;

end.
