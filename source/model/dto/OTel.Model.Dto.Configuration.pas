unit OTel.Model.Dto.Configuration;

interface

uses
  OTel.Model.Dto.Options, OTel.Model.Dto.SignalSettings, OTel.Model.Dto.ConfigurationError;

type
  TOTelSignalSettings = OTel.Model.Dto.SignalSettings.TOTelSignalSettings;
  TOTelOptions = OTel.Model.Dto.Options.TOTelOptions;
  EOTelConfiguration = OTel.Model.Dto.ConfigurationError.EOTelConfiguration;

  TOTelConfiguration = class
  strict private
    FServiceName: string;
    FTracesEndpoint: string;
    FTraceHeaders: string;
    FAdditional: TOTelOptions;
    FSdkDisabled: Boolean;
    FTraceTimeoutMs: Integer;
  public
    constructor Create(const AServiceName, ATracesEndpoint: string); overload;
    constructor Create(const AServiceName, ATracesEndpoint, ATraceHeaders: string;
      ASdkDisabled: Boolean; ATraceTimeoutMs: Integer = 10000); overload;
    destructor Destroy; override;
    property Additional: TOTelOptions read FAdditional;
    property ServiceName: string read FServiceName;
    property TracesEndpoint: string read FTracesEndpoint;
    property TraceHeaders: string read FTraceHeaders;
    property SdkDisabled: Boolean read FSdkDisabled;
    property TraceTimeoutMs: Integer read FTraceTimeoutMs;
  end;

implementation

constructor TOTelConfiguration.Create(const AServiceName, ATracesEndpoint: string);
begin
  Create(AServiceName, ATracesEndpoint, '', False);
end;

constructor TOTelConfiguration.Create(const AServiceName, ATracesEndpoint, ATraceHeaders: string;
  ASdkDisabled: Boolean; ATraceTimeoutMs: Integer);
begin
  inherited Create;
  if ATraceTimeoutMs < 0 then raise EOTelConfiguration.Create('A trace timeout must be nonnegative.');
  FServiceName := AServiceName;
  FTracesEndpoint := ATracesEndpoint;
  FTraceHeaders := ATraceHeaders;
  FSdkDisabled := ASdkDisabled;
  FTraceTimeoutMs := ATraceTimeoutMs;
  FAdditional := TOTelOptions.Create;
end;

destructor TOTelConfiguration.Destroy;
begin
  FAdditional.Free;
  inherited;
end;

end.
