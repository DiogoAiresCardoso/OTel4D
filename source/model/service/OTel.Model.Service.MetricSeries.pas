unit OTel.Model.Service.MetricSeries;

interface

uses
  System.Generics.Collections, OTel.Model.Dto.Metric;

type
  TOTelMetricSeries = class(TOTelMetricDefinition)
  public
    Points: TObjectDictionary<string, TOTelMetricPoint>;
    Overflow: TOTelMetricPoint;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

constructor TOTelMetricSeries.Create;
begin
  inherited;
  Points := TObjectDictionary<string, TOTelMetricPoint>.Create([doOwnsValues]);
end;

destructor TOTelMetricSeries.Destroy;
begin
  Overflow.Free;
  Points.Free;
  inherited;
end;

end.
