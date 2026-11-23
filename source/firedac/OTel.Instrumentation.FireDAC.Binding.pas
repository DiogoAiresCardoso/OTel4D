unit OTel.Instrumentation.FireDAC.Binding;

interface

uses
  System.Classes, OTel.Api;

type
  TOTelFireDACInstrumentation = class(TComponent)
  strict private
    FTracer: TOTelTracer;
    FDuration: TOTelHistogram;
  public
    destructor Destroy; override;
    // Bind or detach while the data module is idle. The host owns the client.
    procedure Bind(Client: TOTelTraceClient);
    procedure Detach;
    property Tracer: TOTelTracer read FTracer;
    property Duration: TOTelHistogram read FDuration;
  end;

implementation

uses
  System.SysUtils;

destructor TOTelFireDACInstrumentation.Destroy;
begin
  Detach;
  inherited;
end;

procedure TOTelFireDACInstrumentation.Bind(Client: TOTelTraceClient);
var
  Tracer: TOTelTracer;
  Histogram: TOTelHistogram;
  Meter: TOTelMeter;
begin
  if (Client = nil) or (csDesigning in ComponentState) then
  begin
    Detach;
    Exit;
  end;
  Tracer := Client.GetTracer('OTel4D.FireDAC');
  try
    Meter := Client.GetMeter('OTel4D.FireDAC');
    try
      Histogram := Meter.CreateHistogram('db.client.operation.duration', 's',
        'Duration of database client operations.',
        [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0]);
    finally
      Meter.Free;
    end;
  except
    Tracer.Free;
    raise;
  end;
  Detach;
  FTracer := Tracer;
  FDuration := Histogram;
end;

procedure TOTelFireDACInstrumentation.Detach;
begin
  FreeAndNil(FDuration);
  FreeAndNil(FTracer);
end;

initialization
  RegisterClass(TOTelFireDACInstrumentation);

finalization
  UnRegisterClass(TOTelFireDACInstrumentation);

end.
