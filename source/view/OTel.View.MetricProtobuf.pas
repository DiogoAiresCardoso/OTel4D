unit OTel.View.MetricProtobuf;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Model.Dto.Metric, OTel.View.Protobuf;

type
  TOTelMetricProtobuf = class
  strict private
    class procedure WriteDouble(Proto: TProtoWriter; Field: Integer; Value: Double); static;
    class procedure WritePoint(Proto: TProtoWriter; Point: TOTelMetricPoint); static;
    class function WriteMetric(Scope: TProtoWriter; Points: TObjectList<TOTelMetricPoint>;
      Index, Limit: Integer): Integer; static;
  public
    class function Encode(const Service: string; Points: TObjectList<TOTelMetricPoint>;
      Offset, Count: Integer): TBytes; static;
  end;

implementation

class procedure TOTelMetricProtobuf.WriteDouble(Proto: TProtoWriter; Field: Integer; Value: Double);
var
  Bits: UInt64;
begin
  Move(Value, Bits, SizeOf(Bits));
  Proto.Fixed64(Field, Bits);
end;

class procedure TOTelMetricProtobuf.WritePoint(Proto: TProtoWriter; Point: TOTelMetricPoint);
var
  Entry: TPair<string, Variant>;
  Bound: Double;
  Bucket: UInt64;
begin
  Proto.Fixed64(2, Point.Start);
  Proto.Fixed64(3, Point.Timestamp);
  if Point.Definition.Kind = mkHistogram then
  begin
    Proto.Fixed64(4, Point.Count);
    WriteDouble(Proto, 5, Point.HistogramSum);
    for Bucket in Point.Buckets do Proto.Fixed64(6, Bucket);
    for Bound in Point.Definition.Bounds do WriteDouble(Proto, 7, Bound);
    for Entry in Point.Attributes do Proto.Attribute(9, Entry.Key, Entry.Value);
  end
  else
  begin
    Proto.Fixed64(6, UInt64(Point.IntegerSum));
    for Entry in Point.Attributes do Proto.Attribute(7, Entry.Key, Entry.Value);
  end;
end;

class function TOTelMetricProtobuf.WriteMetric(Scope: TProtoWriter; Points: TObjectList<TOTelMetricPoint>;
  Index, Limit: Integer): Integer;
var
  Definition: TOTelMetricDefinition;
  Metric, Aggregation, Point: TProtoWriter;
begin
  Definition := Points[Index].Definition;
  Metric := TProtoWriter.Create;
  Aggregation := nil;
  Point := nil;
  try
    Aggregation := TProtoWriter.Create;
    Point := TProtoWriter.Create;
    repeat
      Point.Clear;
      WritePoint(Point, Points[Index]);
      Aggregation.MessageField(1, Point);
      Inc(Index);
      if Index >= Limit then Break;
    until Points[Index].Definition <> Definition;
    Aggregation.Number(2, 2); // AGGREGATION_TEMPORALITY_CUMULATIVE
    Metric.Text(1, Definition.Name);
    if Definition.Description <> '' then Metric.Text(2, Definition.Description);
    if Definition.UnitName <> '' then Metric.Text(3, Definition.UnitName);
    if Definition.Kind = mkHistogram then
      Metric.MessageField(9, Aggregation)
    else
    begin
      if Definition.Kind = mkCounter then Aggregation.Number(3, 1);
      Metric.MessageField(7, Aggregation);
    end;
    Scope.MessageField(2, Metric);
    Result := Index;
  finally
    Point.Free;
    Aggregation.Free;
    Metric.Free;
  end;
end;

class function TOTelMetricProtobuf.Encode(const Service: string; Points: TObjectList<TOTelMetricPoint>;
  Offset, Count: Integer): TBytes;
var
  Resource, Scope, Nested: TProtoWriter;
  Definition: TOTelMetricDefinition;
  ScopeName, Version: string;
  Limit: Integer;
begin
  Resource := TProtoWriter.Create;
  Scope := nil;
  Nested := nil;
  try
    Scope := TProtoWriter.Create;
    Nested := TProtoWriter.Create;
    Nested.Attribute(1, 'service.name', Service);
    Resource.MessageField(1, Nested);
    Limit := Offset + Count;
    while Offset < Limit do
    begin
      Definition := Points[Offset].Definition;
      if (Scope.Size = 0) or (ScopeName <> Definition.Scope) or (Version <> Definition.Version) then
      begin
        if Scope.Size > 0 then Resource.MessageField(2, Scope);
        Scope.Clear;
        ScopeName := Definition.Scope;
        Version := Definition.Version;
        Nested.Clear;
        Nested.Text(1, ScopeName);
        if Version <> '' then Nested.Text(2, Version);
        Scope.MessageField(1, Nested);
      end;
      Offset := WriteMetric(Scope, Points, Offset, Limit);
    end;
    if Scope.Size > 0 then Resource.MessageField(2, Scope);
    Nested.Clear;
    Nested.MessageField(1, Resource);
    Result := Nested.Buffer;
  finally
    Scope.Free;
    Nested.Free;
    Resource.Free;
  end;
end;

end.
