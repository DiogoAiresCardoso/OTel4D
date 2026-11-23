unit OTel.Controller.Configuration;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TOTelConfigurationController = class
  private
    class function Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration; static;
  public
    // Borrows Overrides for this call. The caller owns the returned snapshot.
    class function LoadConfiguration(const Overrides: TOTelOptions = nil): TOTelConfiguration; static;
    class function LoadForClient(const Overrides: TOTelOptions): TOTelConfiguration; static;
  end;

implementation

uses
  OTel.Model.Dao.Environment,
  OTel.Model.Service.Configuration,
  OTel.View.TraceEndpoint;

class function TOTelConfigurationController.LoadConfiguration(const Overrides: TOTelOptions): TOTelConfiguration;
begin
  Result := Resolve(Overrides, False);
end;

class function TOTelConfigurationController.Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
var
  Options: TOTelOptions;
  Endpoint: string;
begin
  Options := TOTelOptions.Create;
  try
    TEnvironmentDao.ReadInto(Options);
    TConfigurationService.ApplyOverridesAndDefaults(Options, Overrides, ForClient);
    if not (ForClient and Options.SdkDisabled) then Endpoint := TTraceEndpointView.Render(Options);
    Result := TOTelConfiguration.Create(Options.ServiceName, Endpoint,
      Options.TraceHeaders, Options.SdkDisabled, Options.TraceTimeoutMs);
    Result.Additional.Logs.Assign(Options.Logs);
    Result.Additional.Metrics.Assign(Options.Metrics);
    Result.Additional.MetricsIntervalMs := Options.MetricsIntervalMs;
  finally
    Options.Free;
  end;
end;

class function TOTelConfigurationController.LoadForClient(const Overrides: TOTelOptions): TOTelConfiguration;
begin
  Result := Resolve(Overrides, True);
end;

end.
