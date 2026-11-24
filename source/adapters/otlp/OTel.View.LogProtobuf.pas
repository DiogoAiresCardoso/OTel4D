unit OTel.View.LogProtobuf;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Model.Dto.Log, OTel.View.Protobuf, OTel.Otlp.Exporter;

type
  TOTelLogProtobuf = class(TInterfacedObject, IOTelBatchEncoder<TOTelLogData>)
  strict private
    procedure WriteRecord(Data: TOTelLogData; Proto: IProtoWriter);
  public
    function Encode(const Service: string; Batch: TObjectList<TOTelLogData>;
      Offset, Count: Integer): TBytes;
  end;

implementation

procedure TOTelLogProtobuf.WriteRecord(Data: TOTelLogData; Proto: IProtoWriter);
const
  LevelText: array[TOTelLogLevel] of string = ('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL');
var
  Body: IProtoWriter;
  Pair: TPair<string, Variant>;
begin
  Proto.Fixed64(1, Data.Timestamp);
  Proto.Number(2, Ord(Data.Level) * 4 + 1);
  Proto.Text(3, LevelText[Data.Level]);
  Body := TProtoWriter.Create;
  Body.Text(1, Data.Body);
  Proto.MessageField(5, Body);
  if Assigned(Data.Attributes) then
  begin
    for Pair in Data.Attributes.Entries do Proto.Attribute(6, Pair.Key, Pair.Value);
    if Data.Attributes.Dropped > 0 then Proto.Number(7, Data.Attributes.Dropped);
  end;
  if Data.TraceId <> '' then
  begin
    Proto.Fixed32(8, Data.Flags);
    Proto.Id(9, Data.TraceId);
    Proto.Id(10, Data.SpanId);
  end;
  Proto.Fixed64(11, Data.ObservedTimestamp);
end;

function TOTelLogProtobuf.Encode(const Service: string; Batch: TObjectList<TOTelLogData>;
  Offset, Count: Integer): TBytes;
var
  I: Integer;
  Resource, Scope, Nested: IProtoWriter;
  Data: TOTelLogData;
  Name, Version: string;
begin
  Resource := TProtoWriter.Create;
  Scope := TProtoWriter.Create;
  Nested := TProtoWriter.Create;
  Nested.Attribute(1, 'service.name', Service);
  Resource.MessageField(1, Nested);
  for I := Offset to Offset + Count - 1 do
  begin
    Data := Batch[I];
    if (Scope.Size = 0) or (Name <> Data.Scope) or (Version <> Data.Version) then
    begin
      if Scope.Size > 0 then Resource.MessageField(2, Scope);
      Scope.Clear;
      Name := Data.Scope;
      Version := Data.Version;
      Nested.Clear;
      Nested.Text(1, Name);
      if Version <> '' then Nested.Text(2, Version);
      Scope.MessageField(1, Nested);
    end;
    Nested.Clear;
    WriteRecord(Data, Nested);
    Scope.MessageField(2, Nested);
  end;
  if Scope.Size > 0 then Resource.MessageField(2, Scope);
  Nested.Clear;
  Nested.MessageField(1, Resource);
  Result := Nested.Buffer;
end;

end.
