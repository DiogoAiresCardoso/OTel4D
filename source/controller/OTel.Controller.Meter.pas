unit OTel.Controller.Meter;

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

  TOTelCounter = class(TOTelMetricInstrument)
  public
    procedure Add(Increment: Int64; const Attributes: TOTelAttributes = nil);
  end;

  TOTelHistogram = class(TOTelMetricInstrument)
  public
    procedure RecordValue(Value: Double; const Attributes: TOTelAttributes = nil);
  end;

  TOTelMeter = class
  strict private
    FStore: IOTelMetricStore;
    FScope, FVersion: string;
    function Define(const Name, UnitName, Description: string; Kind: TOTelMetricKind;
      const Bounds: array of Double): TOTelMetricDefinition;
  public
    constructor Create(const Store: IOTelMetricStore; const Scope, Version: string);
    function CreateCounter(const Name, UnitName: string; const Description: string = ''): TOTelCounter;
    function CreateUpDownCounter(const Name, UnitName: string; const Description: string = ''): TOTelCounter;
    function CreateHistogram(const Name, UnitName: string;
      const Description: string = ''): TOTelHistogram; overload;
    function CreateHistogram(const Name, UnitName, Description: string;
      const Bounds: array of Double): TOTelHistogram; overload;
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

procedure TOTelCounter.Add(Increment: Int64; const Attributes: TOTelAttributes);
begin
  Measure(Increment, 0, Attributes);
end;

procedure TOTelHistogram.RecordValue(Value: Double; const Attributes: TOTelAttributes);
begin
  Measure(0, Value, Attributes);
end;

constructor TOTelMeter.Create(const Store: IOTelMetricStore; const Scope, Version: string);
begin
  inherited Create;
  FStore := Store;
  FScope := Copy(Scope, 1, 256);
  if FScope = '' then FScope := 'OTel4D';
  FVersion := Copy(Version, 1, 128);
end;

function TOTelMeter.Define(const Name, UnitName, Description: string; Kind: TOTelMetricKind;
  const Bounds: array of Double): TOTelMetricDefinition;
begin
  if Assigned(FStore) then
    Result := FStore.RegisterInstrument(FScope, FVersion, Name, UnitName, Description, Kind, Bounds)
  else
    Result := nil;
end;

function TOTelMeter.CreateCounter(const Name, UnitName, Description: string): TOTelCounter;
begin
  Result := TOTelCounter.Create(FStore, Define(Name, UnitName, Description, mkCounter, []));
end;

function TOTelMeter.CreateUpDownCounter(const Name, UnitName, Description: string): TOTelCounter;
begin
  Result := TOTelCounter.Create(FStore, Define(Name, UnitName, Description, mkUpDownCounter, []));
end;

function TOTelMeter.CreateHistogram(const Name, UnitName, Description: string): TOTelHistogram;
begin
  Result := CreateHistogram(Name, UnitName, Description,
    [0.0, 5.0, 10.0, 25.0, 50.0, 75.0, 100.0, 250.0, 500.0, 750.0,
     1000.0, 2500.0, 5000.0, 7500.0, 10000.0]);
end;

function TOTelMeter.CreateHistogram(const Name, UnitName, Description: string;
  const Bounds: array of Double): TOTelHistogram;
begin
  Result := TOTelHistogram.Create(FStore, Define(Name, UnitName, Description, mkHistogram, Bounds));
end;

end.
