unit OTel.Controller.MetricInstrument;

interface

uses
  OTel.Model.Dto.Metric, OTel.Model.Dto.Telemetry, OTel.Model.Service.MetricStore;

type
  TOTelMetricInstrument = class
  strict private
    FStore: IOTelMetricStore;
    FDefinition: TOTelMetricDefinition;
  protected
    procedure Measure(Increment: Int64; Measurement: Double; const Attributes: TOTelAttributes);
  public
    constructor Create(const Store: IOTelMetricStore; Definition: TOTelMetricDefinition);
  end;

implementation

constructor TOTelMetricInstrument.Create(const Store: IOTelMetricStore; Definition: TOTelMetricDefinition);
begin
  inherited Create;
  FStore := Store;
  FDefinition := Definition;
end;

procedure TOTelMetricInstrument.Measure(Increment: Int64; Measurement: Double; const Attributes: TOTelAttributes);
begin
  if Assigned(FDefinition) then FStore.Measure(FDefinition, Increment, Measurement, Attributes);
end;

end.
