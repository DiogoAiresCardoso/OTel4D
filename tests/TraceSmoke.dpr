program TraceSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, OTel.Api;

const
  RemoteParent = '00-0123456789abcdef0123456789abcdef-0123456789abcdef-01';
  RemoteState = 'vendor=upstream';
  Unsampled = '00-0123456789abcdef0123456789abcdef-0123456789abcdef-00';

type
  TTraceSmoke = class
  strict private
    class procedure Check(Test: Boolean; const Reason: string); static;
    class procedure Emit(Tracer: TOTelTracer); static;
    class procedure FillQueue(Tracer: TOTelTracer); static;
    class procedure EmitLargeBatch(Tracer: TOTelTracer); static;
    class procedure Disabled; static;
  public
    class procedure Run; static;
  end;

class procedure TTraceSmoke.Check(Test: Boolean; const Reason: string);
begin
  if not Test then raise Exception.Create(Reason);
end;

class procedure TTraceSmoke.Disabled;
var
  Options: TOTelOptions;
  Client: TOTelTraceClient;
  Tracer: TOTelTracer;
  Span: TOTelSpan;
begin
  Options := TOTelOptions.Create;
  try
    Options.SdkDisabled := True;
    Options.TraceProtocol := 'grpc';
    Options.TracesEndpoint := 'unused when disabled';
    Options.TraceHeaders := 'unused when disabled';
    Client := TOTel.Open(Options);
    try
      Tracer := Client.GetTracer('disabled');
      try
        Span := Tracer.StartSpan('disabled', skServer, RemoteParent, RemoteState);
        try
          Check(not Span.IsRecording and (Span.TraceParent = RemoteParent)
            and (Span.TraceState = RemoteState), 'Disabled SDK lost the incoming context.');
        finally
          Span.Free;
        end;
        Span := Tracer.StartSpan('disabled.root');
        try
          Check(Span.TraceParent = '', 'Disabled SDK generated a root.');
        finally
          Span.Free;
        end;
      finally
        Tracer.Free;
      end;
    finally
      Client.Free;
    end;
  finally
    Options.Free;
  end;
end;

class procedure TTraceSmoke.Emit(Tracer: TOTelTracer);
var
  Server, Local, Other: TOTelSpan;
  FirstRoot: string;
begin
  Server := Tracer.StartSpan('orders.receive', skServer, RemoteParent, RemoteState);
  try
    Server.SetAttribute('order.number', Int64(3000000000));
    Server.SetAttribute('order.number', Int64(-3000000000));
    Server.SetAttribute('cached', True);
    Server.SetAttribute('ratio', Double(0.75));
    Server.SetAttribute('label', 'caf' + #$00E9);
    Server.AddEvent('received');
    Server.WithContext(
      procedure
      var
        Child: TOTelSpan;
      begin
        Child := Tracer.StartSpan('orders.query', skClient);
        try
          try
            raise EConvertError.Create('fixture message');
          except
            on E: EConvertError do
            begin
              Child.RecordException(E);
              Child.SetStatus(ssError, 'conversion failed');
            end;
          end;
        finally
          Child.Free;
        end;
      end);
    Server.Finish;
    Server.Finish;
    Check(not Server.IsRecording, 'Finished span is still recording.');
  finally
    Server.Free;
  end;
  Check(TOTelTraceContext.CurrentParent = '', 'Ambient context leaked.');
  Local := Tracer.StartSpan('orders.root');
  try
    FirstRoot := Copy(Local.TraceParent, 4, 32);
    try
      Local.WithContext(procedure begin raise EAbort.Create('business exception'); end);
    except
      on EAbort do Check(TOTelTraceContext.CurrentParent = '', 'Context leaked after an exception.');
    end;
    Local.SetStatus(ssOk);
  finally
    Local.Free;
  end;
  Other := Tracer.StartSpan('orders.other', skInternal, 'invalid');
  try
    Check(FirstRoot <> Copy(Other.TraceParent, 4, 32), 'Two roots shared a trace ID.');
  finally
    Other.Free;
  end;
  Other := Tracer.StartSpan('unsampled', skServer, Unsampled);
  try
    Check(not Other.IsRecording and (Copy(Other.TraceParent, 54, 2) = '00'), 'Upstream sampling lost.');
  finally
    Other.Free;
  end;
end;

class procedure TTraceSmoke.FillQueue(Tracer: TOTelTracer);
var
  I: Integer;
  Span: TOTelSpan;
begin
  for I := 1 to 3000 do
  begin
    Span := Tracer.StartSpan('queue.pressure');
    try
      Span.SetAttribute('sequence', Int64(I));
    finally
      Span.Free;
    end;
  end;
end;

class procedure TTraceSmoke.EmitLargeBatch(Tracer: TOTelTracer);
var
  I, J: Integer;
  Span: TOTelSpan;
  Payload: string;
begin
  Payload := StringOfChar(#$00E1, 1024);
  for I := 1 to 128 do
  begin
    Span := Tracer.StartSpan('orders.large');
    try
      Span.SetAttribute('sequence', Int64(I));
      for J := 1 to 31 do Span.SetAttribute('synthetic.key.' + IntToStr(J), Payload);
    finally
      Span.Free;
    end;
  end;
end;

class procedure TTraceSmoke.Run;
var
  Client: TOTelTraceClient;
  Tracer: TOTelTracer;
  Late: TOTelSpan;
  Success: Boolean;
begin
  Disabled;
  Client := TOTel.Open;
  Tracer := nil;
  try
    try
      Tracer := Client.GetTracer('orders.delphi', '1.0');
      if ParamStr(1) = 'pressure' then FillQueue(Tracer)
      else if ParamStr(1) = 'large' then EmitLargeBatch(Tracer)
      else Emit(Tracer);
      if (ParamStr(1) = 'pressure') or (ParamStr(1) = 'delayed') then
      begin
        Check(not Client.ForceFlush(0), 'An immediate flush acknowledged pending spans.');
        Check(not Client.Shutdown(0), 'An immediate shutdown acknowledged pending spans.');
        Writeln('release receiver');
        Flush(Output);
      end;
      Success := Client.ForceFlush(15000);
      Check(Client.Shutdown(15000) = Success, 'Repeated processing changed the result.');
      Check(Client.Shutdown(0) = Success, 'Shutdown is not idempotent.');
      Writeln('flush=', Ord(Success), ' dropped=', Client.DroppedSpans,
        ' rejected=', Client.RejectedSpans, ' warnings=', Client.DeliveryWarnings);
      if ParamStr(1) = 'pressure' then Check((not Success) and (Client.DroppedSpans > 0), 'Expected local drops.')
      else if ParamStr(1) <> 'expect-loss' then Check(Success, 'Trace delivery failed.');
    finally
      Client.Free;
    end;
    Late := Tracer.StartSpan('after.shutdown');
    try
      Check(not Late.IsRecording, 'A tracer outlived the client and continued recording.');
    finally
      Late.Free;
    end;
  finally
    Tracer.Free;
  end;
end;

begin
  try
    TTraceSmoke.Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
