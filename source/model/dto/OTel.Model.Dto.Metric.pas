unit OTel.Model.Dto.Metric;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TOTelMetricKind = (mkCounter, mkUpDownCounter, mkHistogram);

  TOTelMetricDefinition = class
  public
    Scope, Version, Name, UnitName, Description: string;
    Kind: TOTelMetricKind;
    Bounds: TArray<Double>;
  end;

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
