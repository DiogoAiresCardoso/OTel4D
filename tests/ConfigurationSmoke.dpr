program ConfigurationSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.Windows,
  OTel.Api;

type
  TConfigurationSmoke = class
  strict private
    class procedure Check(Condition: Boolean; const Scenario: string); static;
    class procedure SetVariable(const Name, Value: string); static;
    class procedure CheckValues(const Options: TOTelOptions; const Service, Endpoint: string); static;
    class procedure CheckOverrides; static;
    class procedure CheckInvalidEndpoint(const Endpoint: string); static;
  public
    class procedure Run; static;
  end;

class procedure TConfigurationSmoke.Check(Condition: Boolean; const Scenario: string);
begin
  if not Condition then
    raise Exception.Create(Scenario);
end;

class procedure TConfigurationSmoke.SetVariable(const Name, Value: string);
begin
  if Value = '' then
    Check(Winapi.Windows.SetEnvironmentVariable(PChar(Name), nil) or
      (GetLastError = ERROR_ENVVAR_NOT_FOUND), 'Could not clear a test variable.')
  else
    Check(Winapi.Windows.SetEnvironmentVariable(PChar(Name), PChar(Value)), 'Could not set a test variable.');
end;

class procedure TConfigurationSmoke.CheckInvalidEndpoint(const Endpoint: string);
var
  Options: TOTelOptions;
begin
  Options := TOTelOptions.Create;
  try
    Options.TracesEndpoint := Endpoint;
    try
      TOTelConfigurationController.LoadConfiguration(Options).Free;
    except
      on E: EOTelConfiguration do
      begin
        Check(Pos('private-value', E.Message) = 0, 'Configuration diagnostics exposed the endpoint.');
        Check(Options.TracesEndpoint = Endpoint, 'Error handling modified the input.');
        Exit;
      end;
    end;
    raise Exception.Create('An invalid endpoint was accepted.');
  finally
    Options.Free;
  end;
end;

class procedure TConfigurationSmoke.CheckValues(const Options: TOTelOptions; const Service, Endpoint: string);
var
  Config: TOTelConfiguration;
begin
  Config := TOTelConfigurationController.LoadConfiguration(Options);
  try
    Check(Config.ServiceName = Service, 'Incorrect service name');
    Check(Config.TracesEndpoint = Endpoint, 'Incorrect trace destination');
  finally
    Config.Free;
  end;
end;

class procedure TConfigurationSmoke.CheckOverrides;
var
  Options: TOTelOptions;
  Snapshot: TOTelConfiguration;
begin
  Snapshot := nil;
  try
    Options := TOTelOptions.Create;
    try
      Options.Endpoint := 'http://[::1]:4318/prefix';
      CheckValues(Options, 'inventory', 'http://[::1]:4318/prefix/v1/traces');
      Check(Options.ServiceName = '', 'Environment settings leaked into caller options.');
      Options.ServiceName := 'billing';
      Options.TracesEndpoint := 'https://receiver.example/exact%2Fpath?key=a%2Bb';
      Snapshot := TOTelConfigurationController.LoadConfiguration(Options);
      Options.ServiceName := 'worker';
      Options.TracesEndpoint := 'http://receiver.example:/';
      CheckValues(Options, 'worker', Options.TracesEndpoint);
    finally
      Options.Free;
    end;
    Check(Snapshot.ServiceName = 'billing', 'The snapshot did not retain its service name.');
    Check(Snapshot.TracesEndpoint = 'https://receiver.example/exact%2Fpath?key=a%2Bb',
      'The snapshot did not retain its trace endpoint.');
  finally
    Snapshot.Free;
  end;
end;

class procedure TConfigurationSmoke.Run;
var
  Initial: TOTelConfiguration;
begin
  SetVariable('OTEL_SERVICE_NAME', '');
  SetVariable('OTEL_EXPORTER_OTLP_ENDPOINT', '');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', '');
  Initial := TOTelConfigurationController.LoadConfiguration;
  try
    Check(Initial.ServiceName = 'unknown_service:' + ExtractFileName(ParamStr(0)), 'Default service name');
    SetVariable('OTEL_SERVICE_NAME', 'inventory');
    SetVariable('OTEL_EXPORTER_OTLP_ENDPOINT', 'https://receiver.example/otel%2Ftenant/?key=test');
    CheckValues(nil, 'inventory', 'https://receiver.example/otel%2Ftenant/v1/traces?key=test');
    SetVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 'https://receiver.example?route=trace');
    CheckValues(nil, 'inventory', 'https://receiver.example/?route=trace');
    CheckOverrides;
    Check(Initial.TracesEndpoint = 'http://localhost:4318/v1/traces', 'An earlier snapshot changed');
  finally
    Initial.Free;
  end;

  CheckInvalidEndpoint('relative/path');
  CheckInvalidEndpoint('ftp://receiver.example/');
  CheckInvalidEndpoint('http:///missing-host');
  CheckInvalidEndpoint('http://receiver.example:65536/');
  CheckInvalidEndpoint('http://receiver.example:$50/');
  CheckInvalidEndpoint('http://receiver.example:+4318/');
  CheckInvalidEndpoint('http://[::1/traces');
  CheckInvalidEndpoint('http://[]/traces');
  CheckInvalidEndpoint('http://[::1]extra/traces');
  CheckInvalidEndpoint('http://[1:::2]/traces');
  CheckInvalidEndpoint('http://@receiver.example/traces');
  CheckInvalidEndpoint('https://receiver.example:private-value/');
  CheckInvalidEndpoint('https://operator:private-value@receiver.example/');
  CheckInvalidEndpoint('http://receiver.example/path#private-value');
  CheckInvalidEndpoint('http://receiver.example/' + #13 + #10);
end;

begin
  try
    TConfigurationSmoke.Run;
    Writeln('Configuration smoke tests passed.');
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
