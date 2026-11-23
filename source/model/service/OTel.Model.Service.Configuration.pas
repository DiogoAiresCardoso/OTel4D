unit OTel.Model.Service.Configuration;

interface

uses
  OTel.Model.Dto.Configuration;

function ResolveOptions(const Overrides, Environment: TOTelOptions): TOTelOptions;

implementation

uses
  System.SysUtils;

const
  DefaultEndpoint = 'http://localhost:4318';

function DefaultServiceName: string;
var
  ExecutableName: string;
begin
  Result := 'unknown_service';
  ExecutableName := ExtractFileName(ParamStr(0));
  if ExecutableName <> '' then
    Result := Result + ':' + ExecutableName;
end;

function ResolveOptions(const Overrides, Environment: TOTelOptions): TOTelOptions;
begin
  Result := Overrides;
  if Result.ServiceName = '' then
    Result.ServiceName := Environment.ServiceName;
  if Result.ServiceName = '' then
    Result.ServiceName := DefaultServiceName;

  if (Result.TracesEndpoint = '') and (Result.Endpoint = '') then
  begin
    Result.TracesEndpoint := Environment.TracesEndpoint;
    Result.Endpoint := Environment.Endpoint;
  end;
  if (Result.TracesEndpoint = '') and (Result.Endpoint = '') then
    Result.Endpoint := DefaultEndpoint;
end;

end.
