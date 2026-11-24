unit TelemetryDemo.SendThread;

interface

uses
  System.Classes, TelemetryDemo.Session;

type
  TDemoSendThread = class(TThread)
  strict private
    FSession: TDemoTelemetrySession;
    FPort: Integer;
    FTraceId, FSpanId, FErrorMessage: string;
  protected
    procedure Execute; override;
  public
    constructor Create(Session: TDemoTelemetrySession; Port: Integer);
    property TraceId: string read FTraceId;
    property SpanId: string read FSpanId;
    property ErrorMessage: string read FErrorMessage;
  end;

implementation

uses
  System.SysUtils;

constructor TDemoSendThread.Create(Session: TDemoTelemetrySession; Port: Integer);
begin
  inherited Create(True);
  FSession := Session;
  FPort := Port;
end;

procedure TDemoSendThread.Execute;
begin
  try
    FSession.SendSample(FPort, FTraceId, FSpanId);
  except
    on E: Exception do FErrorMessage := E.Message;
  end;
end;

end.
