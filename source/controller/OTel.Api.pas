unit OTel.Api;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TOTelOptions = OTel.Model.Dto.Configuration.TOTelOptions;
  TOTelConfiguration = OTel.Model.Dto.Configuration.TOTelConfiguration;
  EOTelConfiguration = OTel.Model.Dto.Configuration.EOTelConfiguration;

function LoadConfiguration: TOTelConfiguration; overload;
function LoadConfiguration(const Overrides: TOTelOptions): TOTelConfiguration; overload;

implementation

uses
  OTel.Model.Dao.Environment,
  OTel.Model.Service.Configuration,
  OTel.View.TraceEndpoint;

function LoadConfiguration: TOTelConfiguration;
begin
  Result := LoadConfiguration(Default(TOTelOptions));
end;

function LoadConfiguration(const Overrides: TOTelOptions): TOTelConfiguration;
var
  Options: TOTelOptions;
begin
  Options := ResolveOptions(Overrides, ReadEnvironmentOptions);
  Result := TOTelConfiguration.Create(Options.ServiceName, RenderTracesEndpoint(Options));
end;

end.
