unit OTel.View.Protobuf;

interface

uses
  System.Classes, System.SysUtils, OTel.View.ProtobufResponse;

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

  TOTelProtobufResponse = OTel.View.ProtobufResponse.TOTelProtobufResponse;

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


end.
