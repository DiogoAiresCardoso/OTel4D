unit OTel.Model.Dao.Environment;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TEnvironmentDao = class
  strict private
    class function ReadTimeout(const Name: string; out Milliseconds: Integer): Boolean; static;
    class procedure ReadSignal(const Name: string; Settings: TOTelSignalSettings); static;
  public
    // Populates the supplied options object. The caller retains ownership.
    class procedure ReadInto(const Options: TOTelOptions); static;
  end;

implementation

uses
  System.SysUtils;

class function TEnvironmentDao.ReadTimeout(const Name: string; out Milliseconds: Integer): Boolean;
var
  Value: string;
  Ch: Char;
begin
  Value := GetEnvironmentVariable(Name);
  for Ch in Value do
    if not CharInSet(Ch, ['0'..'9']) then Exit(False);
  Result := TryStrToInt(Value, Milliseconds) and (Milliseconds >= 0);
end;

class procedure TEnvironmentDao.ReadSignal(const Name: string; Settings: TOTelSignalSettings);
const
  Prefix = 'OTEL_EXPORTER_OTLP_';
var
  SignalPrefix: string;
  Timeout: Integer;
begin
  SignalPrefix := Prefix + Name + '_';
  Settings.BaseEndpoint := GetEnvironmentVariable(Prefix + 'ENDPOINT');
  if Settings.BaseEndpoint = '' then Settings.BaseEndpoint := 'http://localhost:4318';
  Settings.Endpoint := GetEnvironmentVariable(SignalPrefix + 'ENDPOINT');
  Settings.Headers := GetEnvironmentVariable(SignalPrefix + 'HEADERS');
  if Settings.Headers = '' then Settings.Headers := GetEnvironmentVariable(Prefix + 'HEADERS');
  Settings.Protocol := GetEnvironmentVariable(SignalPrefix + 'PROTOCOL');
  if Settings.Protocol = '' then Settings.Protocol := GetEnvironmentVariable(Prefix + 'PROTOCOL');
  Settings.Exporter := GetEnvironmentVariable('OTEL_' + Name + '_EXPORTER');
  Settings.TimeoutMs := 10000;
  if ReadTimeout(SignalPrefix + 'TIMEOUT', Timeout) then Settings.TimeoutMs := Timeout
  else if ReadTimeout(Prefix + 'TIMEOUT', Timeout) then Settings.TimeoutMs := Timeout;
end;

class procedure TEnvironmentDao.ReadInto(const Options: TOTelOptions);
var
  Timeout: Integer;
begin
  if Options = nil then
    raise EArgumentNilException.Create('Options must be assigned.');
  ReadSignal('LOGS', Options.Logs);
  ReadSignal('METRICS', Options.Metrics);
  Options.MetricsIntervalMs := 60000;
  if ReadTimeout('OTEL_METRIC_EXPORT_INTERVAL', Timeout) and (Timeout > 0) then
    Options.MetricsIntervalMs := Timeout;
  Options.ServiceName := GetEnvironmentVariable('OTEL_SERVICE_NAME');
  Options.Endpoint := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_ENDPOINT');
  Options.TracesEndpoint := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT');
  Options.TraceHeaders := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_TRACES_HEADERS');
  if Options.TraceHeaders = '' then
    Options.TraceHeaders := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_HEADERS');
  Options.SdkDisabled := SameText(GetEnvironmentVariable('OTEL_SDK_DISABLED'), 'true');
  Options.TraceProtocol := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_TRACES_PROTOCOL');
  if Options.TraceProtocol = '' then
    Options.TraceProtocol := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_PROTOCOL');
  Options.TraceTimeoutMs := 10000;
  if ReadTimeout('OTEL_EXPORTER_OTLP_TRACES_TIMEOUT', Timeout) then
    Options.TraceTimeoutMs := Timeout
  else if ReadTimeout('OTEL_EXPORTER_OTLP_TIMEOUT', Timeout) then
    Options.TraceTimeoutMs := Timeout;
end;

end.
