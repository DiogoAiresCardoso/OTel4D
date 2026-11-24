unit OTel.Model.Dto.MetricDefinition;

interface

type
  TOTelMetricKind = (mkCounter, mkUpDownCounter, mkHistogram);

  TOTelMetricDefinition = class
  public
    Scope, Version, Name, UnitName, Description: string;
    Kind: TOTelMetricKind;
    Bounds: TArray<Double>;
  end;

implementation

end.
