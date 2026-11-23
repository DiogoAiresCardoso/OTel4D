unit OTel.Model.Dao.Environment;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TEnvironmentDao = class
  strict private
    class function ReadTimeout(const Name: string; out Milliseconds: Integer): Boolean; static;
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

class procedure TEnvironmentDao.ReadInto(const Options: TOTelOptions);
var
  Timeout: Integer;
begin
  if Options = nil then
    raise EArgumentNilException.Create('Options must be assigned.');
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
