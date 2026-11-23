unit OTel.Model.Service.Configuration;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TConfigurationService = class
  strict private
    class function DefaultServiceName: string; static;
  public
    class procedure ApplyOverridesAndDefaults(const Options, Overrides: TOTelOptions); static;
  end;

implementation

uses
  System.SysUtils;

const
  DefaultEndpoint = 'http://localhost:4318';

class function TConfigurationService.DefaultServiceName: string;
var
  ExecutableName: string;
begin
  Result := 'unknown_service';
  ExecutableName := ExtractFileName(ParamStr(0));
  if ExecutableName <> '' then
    Result := Result + ':' + ExecutableName;
end;

class procedure TConfigurationService.ApplyOverridesAndDefaults(const Options, Overrides: TOTelOptions);
begin
  if Assigned(Overrides) then
  begin
    if Overrides.ServiceName <> '' then
      Options.ServiceName := Overrides.ServiceName;
    if (Overrides.TracesEndpoint <> '') or (Overrides.Endpoint <> '') then
    begin
      Options.TracesEndpoint := Overrides.TracesEndpoint;
      Options.Endpoint := Overrides.Endpoint;
    end;
  end;
  if Options.ServiceName = '' then
    Options.ServiceName := DefaultServiceName;
  if (Options.TracesEndpoint = '') and (Options.Endpoint = '') then
    Options.Endpoint := DefaultEndpoint;
end;

end.
