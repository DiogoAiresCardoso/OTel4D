unit TelemetryDemo.SendThread;

interface

uses
  System.Classes, TelemetryDemo.Session;

type
  TDemoSendThread = class(TThread)
  strict private
    FSession: IDemoTelemetrySession;
    FPort: Integer;
    FScenario: TDemoScenario;
    FTraceId, FSpanId, FErrorMessage: string;
  protected
    procedure Execute; override;
  public
    constructor Create(Session: IDemoTelemetrySession; Port: Integer; Scenario: TDemoScenario);
    property TraceId: string read FTraceId;
    property SpanId: string read FSpanId;
    property ErrorMessage: string read FErrorMessage;
  end;

implementation

uses
  System.SysUtils;

constructor TDemoSendThread.Create(Session: IDemoTelemetrySession; Port: Integer; Scenario: TDemoScenario);
begin
  inherited Create(True);
  FSession := Session;
  FPort := Port;
  FScenario := Scenario;
end;

procedure TDemoSendThread.Execute;
begin
  try
    FSession.SendSample(FPort, FScenario, FTraceId, FSpanId);
  except
    on E: Exception do FErrorMessage := E.Message;
  end;
end;

end.
