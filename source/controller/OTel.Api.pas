unit OTel.Api;

interface

uses
  OTel.Model.Dto.Configuration, OTel.Model.Dto.Span, OTel.Model.Service.TraceContext,
  OTel.Controller.Trace, OTel.Controller.TraceClient;

type
  TOTelOptions = OTel.Model.Dto.Configuration.TOTelOptions;
  TOTelConfiguration = OTel.Model.Dto.Configuration.TOTelConfiguration;
  EOTelConfiguration = OTel.Model.Dto.Configuration.EOTelConfiguration;
  TOTelSpan = OTel.Controller.Trace.TOTelSpan;
  TOTelTracer = OTel.Controller.Trace.TOTelTracer;
  TOTelTraceClient = OTel.Controller.TraceClient.TOTelTraceClient;
  TOTelTraceContext = OTel.Model.Service.TraceContext.TOTelTraceContext;
  TOTelSpanKind = OTel.Model.Dto.Span.TOTelSpanKind;
  TOTelStatus = OTel.Model.Dto.Span.TOTelStatus;

  TOTel = class
  public
    class function Open(const Overrides: TOTelOptions = nil): TOTelTraceClient; static;
  end;

  TOTelConfigurationController = class
  private
    class function Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration; static;
  public
    // Borrows Overrides for this call. The caller owns the returned snapshot.
    class function LoadConfiguration(const Overrides: TOTelOptions = nil): TOTelConfiguration; static;
  end;

const
  skInternal = OTel.Model.Dto.Span.skInternal;
  skServer = OTel.Model.Dto.Span.skServer;
  skClient = OTel.Model.Dto.Span.skClient;
  skProducer = OTel.Model.Dto.Span.skProducer;
  skConsumer = OTel.Model.Dto.Span.skConsumer;
  ssUnset = OTel.Model.Dto.Span.ssUnset;
  ssOk = OTel.Model.Dto.Span.ssOk;
  ssError = OTel.Model.Dto.Span.ssError;

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
  finally
    Options.Free;
  end;
end;

class function TOTel.Open(const Overrides: TOTelOptions): TOTelTraceClient;
var
  Config: TOTelConfiguration;
begin
  Config := TOTelConfigurationController.Resolve(Overrides, True);
  try
    Result := TOTelTraceClient.Create(Config);
  finally
    Config.Free;
  end;
end;

end.
