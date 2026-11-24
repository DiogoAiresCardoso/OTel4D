program TelemetryDemoSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, TelemetryDemo.Session;

type
  IDemoSmoke = interface
    procedure Run(Port: Integer);
  end;

  TDemoSmoke = class(TInterfacedObject, IDemoSmoke)
    procedure Run(Port: Integer);
  end;

procedure TDemoSmoke.Run(Port: Integer);
var
  Session: IDemoTelemetrySession;
  Scenario: TDemoScenario;
  TraceId, SpanId: string;
begin
  Session := TDemoTelemetrySession.Create;
  for Scenario := Low(TDemoScenario) to High(TDemoScenario) do
  begin
    Session.SendSample(Port, Scenario, TraceId, SpanId);
    if (Length(TraceId) <> 32) or (Length(SpanId) <> 16) then
      raise Exception.Create('The demo did not return valid identifiers.');
    Writeln(TraceId);
  end;
end;

var
  Smoke: IDemoSmoke;

begin
  try
    Smoke := TDemoSmoke.Create;
    if ParamCount = 0 then Smoke.Run(4318) else Smoke.Run(StrToInt(ParamStr(1)));
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
