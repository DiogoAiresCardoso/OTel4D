program ConfiguredTelemetry;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, OTel.Api;

type
  IConfiguredTelemetry = interface
    procedure Run(const BaseUrl: string);
  end;

  TConfiguredTelemetry = class(TInterfacedObject, IConfiguredTelemetry)
  strict private
    function OpenClient(const BaseUrl, IngestionToken: string): TOTelTraceClient;
    procedure RecordBatch(Tracer: TOTelTracer; Logger: TOTelLogger;
      Counter: TOTelCounter; InvoiceCount: Int64);
    procedure Flush(Client: TOTelTraceClient; Snapshot, ExpectedTotal: Integer);
  public
    procedure Run(const BaseUrl: string);
  end;

function TConfiguredTelemetry.OpenClient(const BaseUrl, IngestionToken: string): TOTelTraceClient;
const
  ExportProtocol = 'http/protobuf';
  ExportTimeoutMs = 5000;
  ExportIntervalMs = 60000;
var
  Options: TOTelOptions;
  Authorization: string;
begin
  Options := TOTelOptions.Create;
  try
    Options.ServiceName := 'billing-code-demo';
    Options.Endpoint := BaseUrl;
    Options.SdkDisabled := False;
    Options.TraceProtocol := ExportProtocol;
    Options.LogsProtocol := ExportProtocol;
    Options.MetricsProtocol := ExportProtocol;
    Options.TraceTimeoutMs := ExportTimeoutMs;
    Options.LogsTimeoutMs := ExportTimeoutMs;
    Options.MetricsTimeoutMs := ExportTimeoutMs;
    Options.MetricsIntervalMs := ExportIntervalMs;

    if IngestionToken <> '' then
    begin
      Authorization := 'Authorization=Bearer%20' + IngestionToken;
      Options.TraceHeaders := Authorization;
      Options.LogsHeaders := Authorization;
      Options.MetricsHeaders := Authorization;
    end;

    Result := TOTel.Open(Options);
  finally
    Options.Free;
  end;
end;

procedure TConfiguredTelemetry.RecordBatch(Tracer: TOTelTracer; Logger: TOTelLogger;
  Counter: TOTelCounter; InvoiceCount: Int64);
var
  Span: TOTelSpan;
begin
  Span := Tracer.StartSpan('invoice.issue_batch');
  try
    Span.WithContext(
      procedure
      begin
        Span.SetAttribute('invoice.count', InvoiceCount);
        Logger.Emit(llInfo, 'Invoice batch issued');
        Counter.Add(InvoiceCount);
      end);
  finally
    Span.Free;
  end;
end;

procedure TConfiguredTelemetry.Flush(Client: TOTelTraceClient; Snapshot, ExpectedTotal: Integer);
begin
  if not Client.ForceFlush(10000) then
    raise Exception.CreateFmt('Export did not complete for snapshot %d.', [Snapshot]);
  Writeln('Snapshot ', Snapshot, ' flushed. Expected cumulative count: ', ExpectedTotal, '.');
end;

procedure TConfiguredTelemetry.Run(const BaseUrl: string);
const
  Scope = 'example.billing';
var
  Client: TOTelTraceClient;
  Tracer: TOTelTracer;
  Logger: TOTelLogger;
  Meter: TOTelMeter;
  Counter: TOTelCounter;
begin
  Tracer := nil;
  Logger := nil;
  Meter := nil;
  Counter := nil;
  Client := OpenClient(BaseUrl, '');
  try
    Tracer := Client.GetTracer(Scope);
    Logger := Client.GetLogger(Scope);
    Meter := Client.GetMeter(Scope);
    Counter := Meter.CreateCounter('example.invoices.issued', '{invoice}', 'Invoices issued by the sample.');

    RecordBatch(Tracer, Logger, Counter, 2);
    RecordBatch(Tracer, Logger, Counter, 1);
    Flush(Client, 1, 3);

    RecordBatch(Tracer, Logger, Counter, 3);
    Flush(Client, 2, 6);

    RecordBatch(Tracer, Logger, Counter, 2);
    Flush(Client, 3, 8);
  finally
    Counter.Free;
    Meter.Free;
    Logger.Free;
    Tracer.Free;
    try
      if not Client.Shutdown(10000) then
      begin
        Writeln(ErrOutput, 'Telemetry shutdown did not complete successfully.');
        ExitCode := 1;
      end;
    finally
      Client.Free;
    end;
  end;
end;

var
  Example: IConfiguredTelemetry;

begin
  try
    Example := TConfiguredTelemetry.Create;
    if ParamCount = 0 then
      Example.Run('http://127.0.0.1:4318')
    else
      Example.Run(ParamStr(1));
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
