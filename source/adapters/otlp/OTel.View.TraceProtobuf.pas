unit OTel.View.TraceProtobuf;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Model.Dto.Span, OTel.View.Protobuf, OTel.Otlp.Exporter;

type
  TOTelTraceProtobuf = class(TInterfacedObject, IOTelBatchEncoder<TOTelSpanData>)
  strict private
    procedure WriteSpan(Writer: IProtoWriter; Data: TOTelSpanData);
  public
    function Encode(const Service: string; Batch: TObjectList<TOTelSpanData>;
      Offset, Count: Integer): TBytes;
  end;

implementation

procedure TOTelTraceProtobuf.WriteSpan(Writer: IProtoWriter; Data: TOTelSpanData);
var
  Pair: TPair<string, Variant>;
  Event: TOTelEvent;
  Nested: IProtoWriter;
begin
  Writer.Id(1, Data.TraceId);
  Writer.Id(2, Data.SpanId);
  if Data.TraceState <> '' then Writer.Text(3, Data.TraceState);
  Writer.Id(4, Data.ParentId);
  Writer.Text(5, Data.Name);
  Writer.Number(6, Ord(Data.Kind) + 1);
  Writer.Fixed64(7, Data.StartNanos);
  Writer.Fixed64(8, Data.EndNanos);
  for Pair in Data.Attributes do Writer.Attribute(9, Pair.Key, Pair.Value);
  if Data.DroppedAttributes > 0 then Writer.Number(10, Data.DroppedAttributes);
  Nested := TProtoWriter.Create;
  for Event in Data.Events do
  begin
    Nested.Clear;
    Nested.Fixed64(1, Event.TimeNanos);
    Nested.Text(2, Event.Name);
    if Event.ExceptionType <> '' then Nested.Attribute(3, 'exception.type', Event.ExceptionType);
    if Event.ExceptionMessage <> '' then Nested.Attribute(3, 'exception.message', Event.ExceptionMessage);
    Writer.MessageField(11, Nested);
  end;
  if Data.DroppedEvents > 0 then Writer.Number(12, Data.DroppedEvents);
  if Data.Status <> ssUnset then
  begin
    Nested.Clear;
    if Data.StatusMessage <> '' then Nested.Text(2, Data.StatusMessage);
    Nested.Number(3, Ord(Data.Status));
    Writer.MessageField(15, Nested);
  end;
  Writer.Fixed32(16, Data.Flags);
end;

function TOTelTraceProtobuf.Encode(const Service: string; Batch: TObjectList<TOTelSpanData>;
  Offset, Count: Integer): TBytes;
var
  I: Integer;
  ResourceSpans, ScopeSpans, Nested: IProtoWriter;
  Data: TOTelSpanData;
  ScopeName, ScopeVersion: string;
begin
  ResourceSpans := TProtoWriter.Create;
  ScopeSpans := TProtoWriter.Create;
  Nested := TProtoWriter.Create;
  Nested.Attribute(1, 'service.name', Service);
  ResourceSpans.MessageField(1, Nested);
  for I := Offset to Offset + Count - 1 do
  begin
    Data := Batch[I];
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
    WriteSpan(Nested, Data);
    ScopeSpans.MessageField(2, Nested);
  end;
  if ScopeSpans.Size > 0 then ResourceSpans.MessageField(2, ScopeSpans);
  Nested.Clear;
  Nested.MessageField(1, ResourceSpans);
  Result := Nested.Buffer;
end;

end.
