unit OTel.Controller.Histogram;

interface

uses
  OTel.Model.Dto.Telemetry, OTel.Controller.MetricInstrument;

type
  TOTelHistogram = class(TOTelMetricInstrument)
  public
    procedure RecordValue(Value: Double; const Attributes: TOTelAttributes = nil);
  end;

implementation

procedure TOTelHistogram.RecordValue(Value: Double; const Attributes: TOTelAttributes);
begin
  Measure(0, Value, Attributes);
end;

end.
