program ConfigurationSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Winapi.Windows,
  OTel.Api;

procedure Check(const Condition: Boolean; const Scenario: string);
begin
  if not Condition then
    raise Exception.Create(Scenario);
end;

procedure SetVariable(const Name, Value: string);
begin
  if Value = '' then
    Check(Winapi.Windows.SetEnvironmentVariable(PChar(Name), nil) or
      (GetLastError = ERROR_ENVVAR_NOT_FOUND), 'Could not clear a test variable.')
  else
    Check(Winapi.Windows.SetEnvironmentVariable(PChar(Name), PChar(Value)), 'Could not set a test variable.');
end;

procedure CheckInvalidEndpoint(const Endpoint: string);
var
  Options: TOTelOptions;
begin
  Options.TracesEndpoint := Endpoint;
  try
    LoadConfiguration(Options);
  except
    on E: EOTelConfiguration do
    begin
      Check(Pos('private-value', E.Message) = 0, 'Configuration diagnostics exposed the endpoint.');
      Exit;
    end;
  end;
  raise Exception.Create('An invalid endpoint was accepted.');
end;

procedure Run;
var
  Options: TOTelOptions;
  Initial, Config: TOTelConfiguration;
begin
  SetVariable('OTEL_SERVICE_NAME', '');
  SetVariable('OTEL_EXPORTER_OTLP_ENDPOINT', '');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', '');
  Initial := LoadConfiguration;
  Check(Initial.ServiceName = 'unknown_service:' + ExtractFileName(ParamStr(0)), 'Default service name');
  Check(Initial.TracesEndpoint = 'http://localhost:4318/v1/traces', 'Default destination');

  SetVariable('OTEL_SERVICE_NAME', 'inventory');
  SetVariable('OTEL_EXPORTER_OTLP_ENDPOINT', 'https://receiver.example/otel%2Ftenant/?key=test');
  Config := LoadConfiguration;
  Check(Config.ServiceName = 'inventory', 'Environment service name');
  Check(Config.TracesEndpoint = 'https://receiver.example/otel%2Ftenant/v1/traces?key=test', 'Base path and query');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 'https://receiver.example?route=trace');
  Config := LoadConfiguration;
  Check(Config.TracesEndpoint = 'https://receiver.example/?route=trace', 'Signal endpoint at root');

  Options.Endpoint := 'http://[::1]:4318/prefix';
  Config := LoadConfiguration(Options);
  Check(Config.ServiceName = 'inventory', 'Inherit service name independently');
  Check(Config.TracesEndpoint = 'http://[::1]:4318/prefix/v1/traces', 'Code base overrides environment');
  Options.ServiceName := 'billing';
  Options.TracesEndpoint := 'https://receiver.example/exact%2Fpath?key=a%2Bb';
  Config := LoadConfiguration(Options);
  Check(Config.ServiceName = 'billing', 'Code service name');
  Check(Config.TracesEndpoint = Options.TracesEndpoint, 'Code signal override preserved');
  Options.TracesEndpoint := 'http://receiver.example:/';
  Config := LoadConfiguration(Options);
  Check(Config.TracesEndpoint = Options.TracesEndpoint, 'Empty port uses the scheme default');
  Check(Initial.TracesEndpoint = 'http://localhost:4318/v1/traces', 'An earlier snapshot changed');

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
    Run;
    Writeln('Configuration smoke tests passed.');
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
