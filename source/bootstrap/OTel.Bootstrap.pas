unit OTel.Bootstrap;

interface

uses
  OTel.Model.Dto.Configuration, OTel.Application.Ports;

type
  IOTelBootstrap = interface
    function Open(const Config: TOTelConfiguration): IOTelSession;
    function ResolveConfiguration(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
  end;

  TOTelBootstrap = class(TInterfacedObject, IOTelBootstrap)
  public
    function Open(const Config: TOTelConfiguration): IOTelSession;
    function ResolveConfiguration(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
  end;

implementation

uses
  System.SysUtils, OTel.Application.Session, OTel.Bootstrap.Signals, OTel.Windows.Clock,
  OTel.Application.Configuration, OTel.Model.Service.Configuration, OTel.Model.Dao.Environment,
  OTel.View.TraceEndpoint;

function TOTelBootstrap.Open(const Config: TOTelConfiguration): IOTelSession;
var
  Clock: IOTelClock;
  Factory: IOTelSignalFactory;
  Endpoint: IOTelEndpointResolver;
begin
  if Config = nil then raise EArgumentNilException.Create('Config must be assigned.');
  Clock := TOTelWindowsClock.Create;
  Endpoint := TTraceEndpointView.Create;
  Factory := TOTelSignalFactory.Create(Config, Clock, Endpoint);
  Result := TOTelTelemetrySession.Create(Clock, Factory);
end;

function TOTelBootstrap.ResolveConfiguration(const Overrides: TOTelOptions;
  ForClient: Boolean): TOTelConfiguration;
var
  Source: IOTelConfigurationSource;
  Endpoint: IOTelEndpointResolver;
  Policy: IOTelConfigurationPolicy;
  Resolver: IOTelConfigurationResolver;
begin
  Source := TEnvironmentDao.Create;
  Endpoint := TTraceEndpointView.Create;
  Policy := TConfigurationService.Create;
  Resolver := TOTelConfigurationResolver.Create(Source, Endpoint, Policy);
  Result := Resolver.Resolve(Overrides, ForClient);
end;

end.
