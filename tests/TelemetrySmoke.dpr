program TelemetrySmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, System.Math, OTel.Api;

type
  TTelemetrySmoke = class
  strict private
    class procedure EmitLogs(Client: TOTelTraceClient); static;
    class procedure EmitMetrics(Client: TOTelTraceClient); static;
  public
    class procedure Run; static;
  end;

class procedure TTelemetrySmoke.EmitLogs(Client: TOTelTraceClient);
const
  Unsampled = '00-0123456789abcdef0123456789abcdef-0123456789abcdef-00';
var
  Logger: TOTelLogger;
  Tracer: TOTelTracer;
  Span: TOTelSpan;
  Attributes: TOTelAttributes;
  I: Integer;
begin
  Logger := Client.GetLogger('orders.logger', '2');
  try
    if ParamStr(1) = 'pressure' then
    begin
      for I := 1 to 3000 do Logger.Emit(llInfo, 'pressure');
      Writeln('release receiver');
      Flush(Output);
      Exit;
    end;
    Tracer := Client.GetTracer('orders');
    try
      Span := Tracer.StartSpan('orders.handle');
      try
        Attributes := TOTelAttributes.Create;
        try
          Attributes.Put('count', Int64(-3000000000));
          Attributes.Put('cache', True);
          Attributes.Put('ratio', Double(0.5));
          Attributes.Put('message', 'caf' + #$E9);
          Span.WithContext(
            procedure
            begin
              Logger.Emit(llInfo, 'sampled', Attributes, 1700000000000000001);
            end);
          Attributes.Put('message', 'changed after emit');
        finally
          Attributes.Free;
        end;
      finally
        Span.Free;
      end;
      TOTelTraceContext.WithContext(Unsampled, '',
        procedure
        begin
          Logger.Emit(llWarn, 'unsampled');
        end);
      Logger.Emit(llError, 'outside');
    finally
      Tracer.Free;
    end;
  finally
    Logger.Free;
  end;
end;

class procedure TTelemetrySmoke.EmitMetrics(Client: TOTelTraceClient);
var
  Meter: TOTelMeter;
  Counter, Duplicate, Active, Overflow: TOTelCounter;
  Histogram: TOTelHistogram;
  Tags, ReverseTags: TOTelAttributes;
  Producer: TThread;
  I: Integer;
begin
  Meter := Client.GetMeter('orders.metrics', '2');
  Counter := nil;
  Duplicate := nil;
  Active := nil;
  Overflow := nil;
  Histogram := nil;
  Tags := nil;
  ReverseTags := nil;
  try
    Counter := Meter.CreateCounter('orders.completed', '{order}');
    Duplicate := Meter.CreateCounter('ORDERS.COMPLETED', '{order}');
    try
      Meter.CreateUpDownCounter('orders.completed', '{order}').Free;
      if GetEnvironmentVariable('OTEL_METRICS_EXPORTER') <> 'none' then
        raise Exception.Create('Incompatible instrument creation succeeded.');
    except
      on EOTelConfiguration do ;
    end;
    Active := Meter.CreateUpDownCounter('orders.active', '{order}');
    Overflow := Meter.CreateCounter('orders.series', '{order}');
    Histogram := Meter.CreateHistogram('orders.duration', 's', 'Order duration', [0.1, 1.0]);
    Tags := TOTelAttributes.Create;
    ReverseTags := TOTelAttributes.Create;
    Tags.Put('region', 'west');
    Tags.Put('size', Int64(2));
    ReverseTags.Put('size', Int64(2));
    ReverseTags.Put('region', 'west');
    Counter.Add(3000000000, Tags);
    Duplicate.Add(3, ReverseTags);
    Counter.Add(-1, Tags);
    Active.Add(-5);
    Active.Add(2);
    Histogram.RecordValue(0.1);
    Histogram.RecordValue(0.5);
    Histogram.RecordValue(1.0);
    Histogram.RecordValue(2.0);
    Histogram.RecordValue(NaN);
    for I := 1 to 130 do
    begin
      Tags.Put('series', Int64(I));
      Overflow.Add(1, Tags);
    end;
    Producer := TThread.CreateAnonymousThread(
      procedure
      var
        Count: Integer;
      begin
        for Count := 1 to 10000 do Active.Add(1);
      end);
    Producer.FreeOnTerminate := False;
    try
      Producer.Start;
      Client.ForceFlush(15000);
      Producer.WaitFor;
    finally
      Producer.Free;
    end;
    Counter.Add(10, ReverseTags);
  finally
    ReverseTags.Free;
    Tags.Free;
    Histogram.Free;
    Overflow.Free;
    Active.Free;
    Duplicate.Free;
    Counter.Free;
    Meter.Free;
  end;
end;

class procedure TTelemetrySmoke.Run;
var
  Client: TOTelTraceClient;
  Success: Boolean;
begin
  Client := TOTel.Open;
  try
    if ParamStr(1) = 'metrics' then EmitMetrics(Client) else EmitLogs(Client);
    Success := Client.ForceFlush(15000);
    if Client.Shutdown(15000) <> Success then
      raise Exception.Create('Shutdown changed delivery health.');
    Writeln('flush=', Ord(Success), ' logs_dropped=', Client.DroppedLogs,
      ' logs_rejected=', Client.RejectedLogs, ' logs_warnings=', Client.LogDeliveryWarnings,
      ' metrics_rejected=', Client.RejectedMetricPoints, ' metrics_warnings=', Client.MetricDeliveryWarnings,
      ' metrics_invalid=', Client.InvalidMetricMeasurements);
  finally
    Client.Free;
  end;
end;

begin
  try
    TTelemetrySmoke.Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
