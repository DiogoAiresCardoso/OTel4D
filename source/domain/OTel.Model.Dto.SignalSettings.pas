unit OTel.Model.Dto.SignalSettings;

interface

type
  TOTelSignalSettings = class
  public
    BaseEndpoint, Endpoint, Headers, Protocol, Exporter: string;
    TimeoutMs: Integer;
    constructor Create;
    procedure Assign(Source: TOTelSignalSettings);
    procedure ApplyOverrides(Overrides: TOTelSignalSettings; const BaseOverride: string);
  end;

implementation

constructor TOTelSignalSettings.Create;
begin
  inherited;
  TimeoutMs := -1;
end;

procedure TOTelSignalSettings.Assign(Source: TOTelSignalSettings);
begin
  BaseEndpoint := Source.BaseEndpoint;
  Endpoint := Source.Endpoint;
  Headers := Source.Headers;
  Protocol := Source.Protocol;
  Exporter := Source.Exporter;
  TimeoutMs := Source.TimeoutMs;
end;

procedure TOTelSignalSettings.ApplyOverrides(Overrides: TOTelSignalSettings; const BaseOverride: string);
begin
  if Overrides.BaseEndpoint <> '' then
  begin
    BaseEndpoint := Overrides.BaseEndpoint;
    Endpoint := '';
  end
  else if BaseOverride <> '' then
  begin
    BaseEndpoint := BaseOverride;
    Endpoint := '';
  end;
  if Overrides.Exporter <> '' then Exporter := Overrides.Exporter;
  if Overrides.Endpoint <> '' then Endpoint := Overrides.Endpoint;
  if Overrides.Headers <> '' then Headers := Overrides.Headers;
  if Overrides.Protocol <> '' then Protocol := Overrides.Protocol;
  if Overrides.TimeoutMs >= 0 then TimeoutMs := Overrides.TimeoutMs;
end;

end.
