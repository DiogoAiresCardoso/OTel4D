program TelemetrySmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, OTel.Api;

type
  TTelemetrySmoke = class
  strict private
    class procedure EmitLogs(Client: TOTelTraceClient); static;
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

class procedure TTelemetrySmoke.Run;
var
  Client: TOTelTraceClient;
  Success: Boolean;
begin
  Client := TOTel.Open;
  try
    EmitLogs(Client);
    Success := Client.ForceFlush(15000);
    if Client.Shutdown(15000) <> Success then
      raise Exception.Create('Shutdown changed delivery health.');
    Writeln('flush=', Ord(Success), ' logs_dropped=', Client.DroppedLogs,
      ' logs_rejected=', Client.RejectedLogs, ' logs_warnings=', Client.LogDeliveryWarnings);
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
