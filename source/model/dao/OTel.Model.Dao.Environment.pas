unit OTel.Model.Dao.Environment;

interface

uses
  OTel.Model.Dto.Configuration;

type
  TEnvironmentDao = class
  public
    // Populates the supplied options object. The caller retains ownership.
    class procedure ReadInto(const Options: TOTelOptions); static;
  end;

implementation

uses
  System.SysUtils;

class procedure TEnvironmentDao.ReadInto(const Options: TOTelOptions);
begin
  if Options = nil then
    raise EArgumentNilException.Create('Options must be assigned.');
  Options.ServiceName := GetEnvironmentVariable('OTEL_SERVICE_NAME');
  Options.Endpoint := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_ENDPOINT');
  Options.TracesEndpoint := GetEnvironmentVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT');
end;

end.
