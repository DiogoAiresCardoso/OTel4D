unit OTel.Model.Dto.Metric;

interface

uses
  System.Generics.Collections, OTel.Model.Dto.MetricDefinition;

type
  TOTelMetricKind = OTel.Model.Dto.MetricDefinition.TOTelMetricKind;

  TOTelMetricDefinition = OTel.Model.Dto.MetricDefinition.TOTelMetricDefinition;

  TOTelMetricPoint = class
  public
    Definition: TOTelMetricDefinition;
    Attributes: TArray<TPair<string, Variant>>;
    Start, Timestamp, Count: UInt64;
    IntegerSum: Int64;
    HistogramSum: Double;
    Buckets: TArray<UInt64>;
    function Snapshot(Time: UInt64): TOTelMetricPoint;
  end;

const
  mkCounter = OTel.Model.Dto.MetricDefinition.mkCounter;
  mkUpDownCounter = OTel.Model.Dto.MetricDefinition.mkUpDownCounter;
  mkHistogram = OTel.Model.Dto.MetricDefinition.mkHistogram;

implementation

function TOTelMetricPoint.Snapshot(Time: UInt64): TOTelMetricPoint;
begin
  Result := TOTelMetricPoint.Create;
  try
    Result.Definition := Definition;
    Result.Attributes := Attributes;
    Result.Start := Start;
    Result.Timestamp := Time;
    if Result.Timestamp < Start then Result.Timestamp := Start;
    Result.Count := Count;
    Result.IntegerSum := IntegerSum;
    Result.HistogramSum := HistogramSum;
    Result.Buckets := Copy(Buckets);
  except
    Result.Free;
    raise;
  end;
end;

end.
