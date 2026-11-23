unit OTel.View.TraceProtobuf;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Model.Dto.Span;

type
  TOTelTraceProtobuf = class
  public
    class function Encode(const Service: string; Batch: TObjectList<TOTelSpanData>): TBytes; static;
    class function DecodeResponse(const Body: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean; static;
  end;

implementation

uses
  System.Classes, System.Variants;

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
    procedure Span(Data: TOTelSpanData);
    function Buffer: TBytes;
  end;

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

procedure TProtoWriter.Span(Data: TOTelSpanData);
var
  Pair: TPair<string, Variant>;
  Event: TOTelEvent;
  Nested: TProtoWriter;
begin
  Id(1, Data.TraceId);
  Id(2, Data.SpanId);
  if Data.TraceState <> '' then Text(3, Data.TraceState);
  Id(4, Data.ParentId);
  Text(5, Data.Name);
  Number(6, Ord(Data.Kind) + 1);
  Fixed64(7, Data.StartNanos);
  Fixed64(8, Data.EndNanos);
  for Pair in Data.Attributes do Attribute(9, Pair.Key, Pair.Value);
  if Data.DroppedAttributes > 0 then Number(10, Data.DroppedAttributes);
  Nested := TProtoWriter.Create;
  try
    for Event in Data.Events do
    begin
      Nested.Clear;
      Nested.Fixed64(1, Event.TimeNanos);
      Nested.Text(2, Event.Name);
      if Event.ExceptionType <> '' then Nested.Attribute(3, 'exception.type', Event.ExceptionType);
      if Event.ExceptionMessage <> '' then Nested.Attribute(3, 'exception.message', Event.ExceptionMessage);
      MessageField(11, Nested);
    end;
    if Data.DroppedEvents > 0 then Number(12, Data.DroppedEvents);
    if Data.Status <> ssUnset then
    begin
      Nested.Clear;
      if Data.StatusMessage <> '' then Nested.Text(2, Data.StatusMessage);
      Nested.Number(3, Ord(Data.Status));
      MessageField(15, Nested);
    end;
  finally
    Nested.Free;
  end;
  Fixed32(16, Data.Flags);
end;

class function TOTelTraceProtobuf.Encode(const Service: string; Batch: TObjectList<TOTelSpanData>): TBytes;
var
  ResourceSpans, ScopeSpans, Nested: TProtoWriter;
  Data: TOTelSpanData;
  ScopeName, ScopeVersion: string;
begin
  ResourceSpans := TProtoWriter.Create;
  ScopeSpans := nil;
  Nested := nil;
  try
    ScopeSpans := TProtoWriter.Create;
    Nested := TProtoWriter.Create;
    Nested.Attribute(1, 'service.name', Service);
    ResourceSpans.MessageField(1, Nested);
    for Data in Batch do
    begin
      if (ScopeSpans.Size = 0) or (ScopeName <> Data.ScopeName) or (ScopeVersion <> Data.ScopeVersion) then
      begin
        if ScopeSpans.Size > 0 then ResourceSpans.MessageField(2, ScopeSpans);
        ScopeSpans.Clear;
        ScopeName := Data.ScopeName;
        ScopeVersion := Data.ScopeVersion;
        Nested.Clear;
        Nested.Text(1, ScopeName);
        if ScopeVersion <> '' then Nested.Text(2, ScopeVersion);
        ScopeSpans.MessageField(1, Nested);
      end;
      Nested.Clear;
      Nested.Span(Data);
      ScopeSpans.MessageField(2, Nested);
    end;
    if ScopeSpans.Size > 0 then ResourceSpans.MessageField(2, ScopeSpans);
    Nested.Clear;
    Nested.MessageField(1, ResourceSpans);
    Result := Nested.Buffer;
  finally
    Nested.Free;
    ScopeSpans.Free;
    ResourceSpans.Free;
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

class function TOTelTraceProtobuf.DecodeResponse(const Body: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
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
