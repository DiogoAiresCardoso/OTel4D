unit OTel.Application.Configuration;

interface

uses
  OTel.Application.Ports, OTel.Model.Dto.Configuration;

type
  TOTelConfigurationResolver = class(TInterfacedObject, IOTelConfigurationResolver)
  strict private
    FSource: IOTelConfigurationSource;
    FEndpoint: IOTelEndpointResolver;
    FPolicy: IOTelConfigurationPolicy;
    function Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
  public
    constructor Create(const Source: IOTelConfigurationSource; const Endpoint: IOTelEndpointResolver;
      const Policy: IOTelConfigurationPolicy);
  end;

implementation

constructor TOTelConfigurationResolver.Create(const Source: IOTelConfigurationSource;
  const Endpoint: IOTelEndpointResolver; const Policy: IOTelConfigurationPolicy);
begin
  inherited Create;
  FSource := Source;
  FEndpoint := Endpoint;
  FPolicy := Policy;
end;

function TOTelConfigurationResolver.Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
var
  Options: TOTelOptions;
  Endpoint: string;
begin
  Options := TOTelOptions.Create;
  try
    FSource.ReadInto(Options);
    FPolicy.ApplyOverridesAndDefaults(Options, Overrides, ForClient);
    if not (ForClient and Options.SdkDisabled) then Endpoint := FEndpoint.Render(Options);
    Result := TOTelConfiguration.Create(Options.ServiceName, Endpoint,
      Options.TraceHeaders, Options.SdkDisabled, Options.TraceTimeoutMs);
    Result.Additional.Logs.Assign(Options.Logs);
    Result.Additional.Metrics.Assign(Options.Metrics);
    Result.Additional.MetricsIntervalMs := Options.MetricsIntervalMs;
  finally
    Options.Free;
  end;
end;

end.
