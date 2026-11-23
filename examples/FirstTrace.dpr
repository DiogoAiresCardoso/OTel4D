program FirstTrace;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, OTel.Api;

type
  TInvoiceExample = class
  strict private
    class procedure CalculateTotal(Tracer: TOTelTracer); static;
    class procedure IssueInvoice(Tracer: TOTelTracer); static;
  public
    class procedure Run; static;
  end;

class procedure TInvoiceExample.CalculateTotal(Tracer: TOTelTracer);
var
  Span: TOTelSpan;
begin
  Span := Tracer.StartSpan('invoice.calculate_total');
  try
    Span.SetAttribute('invoice.line_count', Int64(3));
  finally
    Span.Free;
  end;
end;

class procedure TInvoiceExample.IssueInvoice(Tracer: TOTelTracer);
var
  Span: TOTelSpan;
begin
  Span := Tracer.StartSpan('invoice.issue');
  try
    Span.WithContext(
      procedure
      begin
        CalculateTotal(Tracer);
      end);
    Span.AddEvent('invoice.calculated');
  finally
    Span.Free;
  end;
end;

class procedure TInvoiceExample.Run;
var
  Client: TOTelTraceClient;
  Tracer: TOTelTracer;
begin
  Client := TOTel.Open;
  try
    try
      Tracer := Client.GetTracer('example.billing', '1.0');
      try
        IssueInvoice(Tracer);
      finally
        Tracer.Free;
      end;
    finally
      if Client.Shutdown(10000) then
        Writeln('Trace delivery completed.')
      else
      begin
        Writeln(ErrOutput, 'Trace delivery incomplete. Dropped=', Client.DroppedSpans,
          ' rejected=', Client.RejectedSpans, ' warnings=', Client.DeliveryWarnings);
        ExitCode := 1;
      end;
    end;
  finally
    Client.Free;
  end;
end;

begin
  try
    TInvoiceExample.Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
