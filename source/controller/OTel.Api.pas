unit OTel.Api;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TOTelOptions = OTel.Model.Dto.Configuration.TOTelOptions;
  TOTelConfiguration = OTel.Model.Dto.Configuration.TOTelConfiguration;
  EOTelConfiguration = OTel.Model.Dto.Configuration.EOTelConfiguration;

  TOTelConfigurationController = class
  public
    // Borrows Overrides for this call. The caller owns the returned snapshot.
    class function LoadConfiguration(const Overrides: TOTelOptions = nil): TOTelConfiguration; static;
  end;

implementation

uses
  OTel.Model.Dao.Environment,
  OTel.Model.Service.Configuration,
  OTel.View.TraceEndpoint;

class function TOTelConfigurationController.LoadConfiguration(const Overrides: TOTelOptions): TOTelConfiguration;
var
  Options: TOTelOptions;
begin
  Options := TOTelOptions.Create;
  try
    TEnvironmentDao.ReadInto(Options);
    TConfigurationService.ApplyOverridesAndDefaults(Options, Overrides);
    Result := TOTelConfiguration.Create(Options.ServiceName, TTraceEndpointView.Render(Options));
  finally
    Options.Free;
  end;
end;

end.
