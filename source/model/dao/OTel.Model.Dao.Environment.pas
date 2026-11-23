unit OTel.Model.Dao.Environment;

interface

uses
  OTel.Model.Dto.Configuration;

function ReadEnvironmentOptions: TOTelOptions;

implementation

uses
  System.SysUtils;

function ReadEnvironmentOptions: TOTelOptions;
begin
  Result.ServiceName := GetEnvironmentVariable('OTEL_SERVICE_NAME');
  Result.Endpoint := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_ENDPOINT');
  Result.TracesEndpoint := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT');
end;

end.
