program ConfigurationSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  OTel.Application.Ports, Winapi.Windows,
  OTel.Api,
  OTel.Model.Dao.Environment,
  OTel.Model.Service.Configuration,
  OTel.View.TraceEndpoint;

type
  TConfigurationSmoke = class
  strict private
    class procedure Check(Condition: Boolean; const Scenario: string); static;
    class procedure SetVariable(const Name, Value: string); static;
    class procedure CheckValues(const Options: TOTelOptions; const Service, Endpoint: string); static;
    class procedure CheckOverrides; static;
    class procedure CheckDeliverySettings; static;
    class procedure CheckProgrammaticSignals; static;
    class procedure CheckInvalidEndpoint(const Endpoint: string); static;
    class procedure CheckRequiredOptions; static;
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

class procedure TConfigurationSmoke.CheckRequiredOptions;
var
  Source: IOTelConfigurationSource;
  Policy: IOTelConfigurationPolicy;
  Endpoint: IOTelEndpointResolver;
begin
  Source := TEnvironmentDao.Create;
  Policy := TConfigurationService.Create;
  Endpoint := TTraceEndpointView.Create;
  try
    Source.ReadInto(nil);
    raise Exception.Create('The DAO accepted a missing destination object.');
  except
    on EArgumentNilException do ; // Expected for a required argument.
  end;
  try
    Policy.ApplyOverridesAndDefaults(nil, nil);
    raise Exception.Create('The service accepted a missing destination object.');
  except
    on EArgumentNilException do ;
  end;
  try
    Endpoint.Render(nil);
    raise Exception.Create('The view accepted a missing options object.');
  except
    on EArgumentNilException do ;
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
      Options.TracesEndpoint := '';
      Options.Endpoint := 'https://receiver.example/tenant%2fone?value=%2520';
      CheckValues(Options, 'worker', 'https://receiver.example/tenant%2fone/v1/traces?value=%2520');
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

class procedure TConfigurationSmoke.CheckDeliverySettings;
var
  Options: TOTelOptions;
  Snapshot: TOTelConfiguration;
begin
  SetVariable('OTEL_EXPORTER_OTLP_TIMEOUT', '1200');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_TIMEOUT', 'invalid');
  SetVariable('OTEL_EXPORTER_OTLP_HEADERS', 'x-origin=general');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_HEADERS', 'x-origin=traces');
  SetVariable('OTEL_EXPORTER_OTLP_PROTOCOL', 'grpc');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_PROTOCOL', 'http/protobuf');
  SetVariable('OTEL_SDK_DISABLED', 'TRUE');
  Snapshot := TOTelConfigurationController.LoadConfiguration;
  try
    Check(Snapshot.TraceTimeoutMs = 1200, 'Invalid signal timeout hid the fallback.');
    Check(Snapshot.TraceHeaders = 'x-origin=traces', 'Incorrect header precedence.');
    Check(Snapshot.SdkDisabled, 'Disabled environment setting was ignored.');
  finally
    Snapshot.Free;
  end;
  Options := TOTelOptions.Create;
  try
    Options.SdkDisabled := False;
    Options.TraceHeaders := 'x-origin=host';
    Options.TraceTimeoutMs := 0;
    Snapshot := TOTelConfigurationController.LoadConfiguration(Options);
    try
      Check(not Snapshot.SdkDisabled, 'Explicit enable did not take precedence.');
      Check(Snapshot.TraceTimeoutMs = 0, 'Explicit zero timeout lost.');
      Check(Snapshot.TraceHeaders = 'x-origin=host', 'Explicit header lost.');
    finally
      Snapshot.Free;
    end;
    Options.TraceProtocol := 'grpc';
    try
      TOTel.Open(Options).Free;
      raise Exception.Create('An enabled client accepted gRPC.');
    except
      on EOTelConfiguration do ;
    end;
  finally
    Options.Free;
  end;
end;

class procedure TConfigurationSmoke.CheckProgrammaticSignals;
var
  Options: TOTelOptions;
  Snapshot: TOTelConfiguration;
  Client: TOTelTraceClient;
  Invalid: Boolean;
begin
  SetVariable('OTEL_LOGS_EXPORTER', 'otlp');
  SetVariable('OTEL_METRICS_EXPORTER', 'otlp');
  SetVariable('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', 'http://receiver.example/old');
  Options := TOTelOptions.Create;
  try
    Options.SdkDisabled := False;
    Options.Endpoint := 'http://receiver.example/common';
    Options.Logs.BaseEndpoint := 'http://receiver.example/isolated';
    Options.Logs.Exporter := 'none';
    Options.Metrics.Exporter := 'none';
    Snapshot := TOTelConfigurationController.LoadConfiguration(Options);
    try
      Check(Snapshot.Additional.Logs.Exporter = 'none', 'Direct log exporter override was ignored.');
      Check(Snapshot.Additional.Metrics.Exporter = 'none', 'Direct metric exporter override was ignored.');
      Check(Snapshot.Additional.Logs.BaseEndpoint = Options.Logs.BaseEndpoint, 'Direct log base URL was ignored.');
      Check(Snapshot.Additional.Logs.Endpoint = '', 'Explicit log base did not replace an older exact URL.');
    finally
      Snapshot.Free;
    end;

    Options.LogsProtocol := 'invalid';
    Options.MetricsProtocol := 'invalid';
    Client := TOTel.Open(Options);
    try
      Check(Client.Shutdown(1000), 'Disabled signals should bypass their invalid settings.');
    finally
      Client.Free;
    end;

    Options.Metrics.Exporter := 'otlp';
    Invalid := False;
    try
      TOTel.Open(Options).Free;
    except
      on EOTelConfiguration do Invalid := True;
    end;
    Check(Invalid, 'Invalid active metric protocol should raise at startup.');
  finally
    Options.Free;
    SetVariable('OTEL_LOGS_EXPORTER', '');
    SetVariable('OTEL_METRICS_EXPORTER', '');
    SetVariable('OTEL_EXPORTER_OTLP_LOGS_ENDPOINT', '');
  end;
end;

class procedure TConfigurationSmoke.Run;
var
  Initial: TOTelConfiguration;
begin
  SetVariable('OTEL_SERVICE_NAME', '');
  SetVariable('OTEL_EXPORTER_OTLP_ENDPOINT', '');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', '');
  SetVariable('OTEL_EXPORTER_OTLP_PROTOCOL', '');
  SetVariable('OTEL_EXPORTER_OTLP_TRACES_PROTOCOL', '');
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

  CheckRequiredOptions;
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
  CheckInvalidEndpoint('http://receiver.example/path%');
  CheckInvalidEndpoint('http://receiver.example/path%2');
  CheckInvalidEndpoint('http://receiver.example/?private-value=%ZZ');
  CheckInvalidEndpoint('http://receiver.example/' + #13 + #10);
  CheckDeliverySettings;
  CheckProgrammaticSignals;
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
