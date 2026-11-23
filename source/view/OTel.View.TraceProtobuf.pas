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
  OTel.View.Protobuf;

type
  TTraceWriter = class(TProtoWriter)
  public
    procedure Span(Data: TOTelSpanData);
  end;

procedure TTraceWriter.Span(Data: TOTelSpanData);
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
  ResourceSpans, ScopeSpans: TProtoWriter;
  Nested: TTraceWriter;
  Data: TOTelSpanData;
  ScopeName, ScopeVersion: string;
begin
  ResourceSpans := TProtoWriter.Create;
  ScopeSpans := nil;
  Nested := nil;
  try
    ScopeSpans := TProtoWriter.Create;
    Nested := TTraceWriter.Create;
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

class function TOTelTraceProtobuf.DecodeResponse(const Body: TBytes; out Rejected: UInt64; out Warning: Boolean): Boolean;
begin
  Result := TOTelProtobufResponse.Decode(Body, Rejected, Warning);
end;

end.
