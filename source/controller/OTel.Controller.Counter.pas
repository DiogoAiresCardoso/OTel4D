unit OTel.Controller.Counter;

interface

uses
  OTel.Model.Dto.Telemetry, OTel.Controller.MetricInstrument;

type
  TOTelCounter = class(TOTelMetricInstrument)
  public
    procedure Add(Increment: Int64; const Attributes: TOTelAttributes = nil);
  end;

implementation

procedure TOTelCounter.Add(Increment: Int64; const Attributes: TOTelAttributes);
begin
  Measure(Increment, 0, Attributes);
end;

end.
