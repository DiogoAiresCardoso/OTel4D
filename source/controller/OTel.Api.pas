unit OTel.Api;

interface

uses
  OTel.Model.Dto.Configuration, OTel.Model.Dto.Span, OTel.Model.Service.TraceContext,
  OTel.Controller.Trace, OTel.Controller.TraceClient, OTel.Model.Dto.Telemetry,
  OTel.Model.Dto.Log, OTel.Controller.Logger, OTel.Controller.Meter,
  OTel.Controller.Configuration;

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

  TOTelLogger = OTel.Controller.Logger.TOTelLogger;
  TOTelAttributes = OTel.Model.Dto.Telemetry.TOTelAttributes;
  TOTelLogLevel = OTel.Model.Dto.Log.TOTelLogLevel;

  TOTelMeter = OTel.Controller.Meter.TOTelMeter;
  TOTelCounter = OTel.Controller.Meter.TOTelCounter;
  TOTelHistogram = OTel.Controller.Meter.TOTelHistogram;

  TOTel = class
  public
    class function Open(const Overrides: TOTelOptions = nil): TOTelTraceClient; static;
  end;

  TOTelConfigurationController = OTel.Controller.Configuration.TOTelConfigurationController;

const
  llTrace = OTel.Model.Dto.Log.llTrace;
  llDebug = OTel.Model.Dto.Log.llDebug;
  llInfo = OTel.Model.Dto.Log.llInfo;
  llWarn = OTel.Model.Dto.Log.llWarn;
  llError = OTel.Model.Dto.Log.llError;
  llFatal = OTel.Model.Dto.Log.llFatal;
  skInternal = OTel.Model.Dto.Span.skInternal;
  skServer = OTel.Model.Dto.Span.skServer;
  skClient = OTel.Model.Dto.Span.skClient;
  skProducer = OTel.Model.Dto.Span.skProducer;
  skConsumer = OTel.Model.Dto.Span.skConsumer;
  ssUnset = OTel.Model.Dto.Span.ssUnset;
  ssOk = OTel.Model.Dto.Span.ssOk;
  ssError = OTel.Model.Dto.Span.ssError;

implementation

class function TOTel.Open(const Overrides: TOTelOptions): TOTelTraceClient;
var
  Config: TOTelConfiguration;
begin
  Config := TOTelConfigurationController.LoadForClient(Overrides);
  try
    Result := TOTelTraceClient.Create(Config);
  finally
    Config.Free;
  end;
end;

end.
