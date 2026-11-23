unit OTel.Model.Service.Configuration;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TConfigurationService = class
  strict private
    class function DefaultServiceName: string; static;
  public
    // Updates the supplied options in place. Overrides may be nil and is read-only.
    class procedure ApplyOverridesAndDefaults(const Options, Overrides: TOTelOptions;
      SkipDisabledExport: Boolean = False); static;
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

class procedure TConfigurationService.ApplyOverridesAndDefaults(const Options, Overrides: TOTelOptions;
  SkipDisabledExport: Boolean);
begin
  if Options = nil then
    raise EArgumentNilException.Create('Options must be assigned.');
  if Assigned(Overrides) then
  begin
    Options.Logs.ApplyOverrides(Overrides.Logs, Overrides.Endpoint);
    Options.Metrics.ApplyOverrides(Overrides.Metrics, Overrides.Endpoint);
    if Overrides.MetricsIntervalMs > 0 then Options.MetricsIntervalMs := Overrides.MetricsIntervalMs;
    if Overrides.TraceHeaders <> '' then Options.TraceHeaders := Overrides.TraceHeaders;
    if Overrides.TraceProtocol <> '' then Options.TraceProtocol := Overrides.TraceProtocol;
    if Overrides.TraceTimeoutMs >= 0 then Options.TraceTimeoutMs := Overrides.TraceTimeoutMs;
    if Overrides.HasSdkDisabled then Options.SdkDisabled := Overrides.SdkDisabled;
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
  if SkipDisabledExport and Options.SdkDisabled then Exit;
  if (Options.TraceProtocol <> '') and not SameText(Options.TraceProtocol, 'http/protobuf') then
    raise EOTelConfiguration.Create('The supported trace protocol is http/protobuf.');
  if Options.TraceTimeoutMs < 0 then Options.TraceTimeoutMs := 10000;
  if (Options.TracesEndpoint = '') and (Options.Endpoint = '') then
    Options.Endpoint := DefaultEndpoint;
end;

end.
