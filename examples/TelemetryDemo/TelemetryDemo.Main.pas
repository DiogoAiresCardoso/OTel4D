unit TelemetryDemo.Main;

interface

uses
  System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls,
  TelemetryDemo.Session, TelemetryDemo.SendThread;

type
  TTelemetryDemoForm = class(TForm)
    TitleLabel: TLabel;
    SummaryLabel: TLabel;
    ConnectionGroup: TGroupBox;
    PortLabel: TLabel;
    PortEdit: TEdit;
    ScenarioLabel: TLabel;
    ScenarioCombo: TComboBox;
    SendButton: TButton;
    ResultGroup: TGroupBox;
    StatusLabel: TLabel;
    TraceIdLabel: TLabel;
    TraceIdEdit: TEdit;
    SpanIdLabel: TLabel;
    SpanIdEdit: TEdit;
    CompletionTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SendButtonClick(Sender: TObject);
    procedure CompletionTimerTimer(Sender: TObject);
  strict private
    FSession: IDemoTelemetrySession;
    FSendThread: TDemoSendThread;
    FClosePending: Boolean;
    procedure SetSending(Sending: Boolean);
  public
    destructor Destroy; override;
  end;

var
  TelemetryDemoForm: TTelemetryDemoForm;

implementation

uses
  System.SysUtils, Winapi.Windows;

{$R *.dfm}

procedure TTelemetryDemoForm.FormCreate(Sender: TObject);
var
  Port: string;
  Scenario: TDemoScenario;
begin
  FSession := TDemoTelemetrySession.Create;
  Port := Trim(GetEnvironmentVariable('OTLP_HTTP_PORT'));
  if Port <> '' then PortEdit.Text := Port;
  for Scenario := Low(TDemoScenario) to High(TDemoScenario) do
    ScenarioCombo.Items.Add(FSession.ScenarioCaption(Scenario));
  ScenarioCombo.ItemIndex := Ord(dsSuccess);
end;

destructor TTelemetryDemoForm.Destroy;
begin
  if Assigned(CompletionTimer) then CompletionTimer.Enabled := False;
  FSendThread.Free;
  FSession := nil;
  inherited;
end;

procedure TTelemetryDemoForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FSendThread = nil;
  if CanClose then Exit;
  FClosePending := True;
  StatusLabel.Caption := 'Waiting for the current send before closing...';
end;

procedure TTelemetryDemoForm.SetSending(Sending: Boolean);
begin
  SendButton.Enabled := not Sending;
  PortEdit.Enabled := not Sending;
  ScenarioCombo.Enabled := not Sending;
end;

procedure TTelemetryDemoForm.SendButtonClick(Sender: TObject);
var
  Port: Integer;
begin
  if Assigned(FSendThread) then Exit;
  if not TryStrToInt(Trim(PortEdit.Text), Port) or (Port < 1) or (Port > 65535) then
  begin
    StatusLabel.Caption := 'Enter a Collector port between 1 and 65535.';
    PortEdit.SetFocus;
    Exit;
  end;

  TraceIdEdit.Clear;
  SpanIdEdit.Clear;
  StatusLabel.Caption := 'Sending traces, logs and metrics...';
  try
    FSendThread := TDemoSendThread.Create(FSession, Port, TDemoScenario(ScenarioCombo.ItemIndex));
    SetSending(True);
    FSendThread.Start;
    CompletionTimer.Enabled := True;
  except
    on E: Exception do
    begin
      FreeAndNil(FSendThread);
      SetSending(False);
      StatusLabel.Caption := E.Message;
    end;
  end;
end;

procedure TTelemetryDemoForm.CompletionTimerTimer(Sender: TObject);
begin
  if FSendThread = nil then Exit;
  if WaitForSingleObject(FSendThread.Handle, 0) <> WAIT_OBJECT_0 then Exit;

  CompletionTimer.Enabled := False;
  TraceIdEdit.Text := FSendThread.TraceId;
  SpanIdEdit.Text := FSendThread.SpanId;
  if FSendThread.ErrorMessage = '' then
    StatusLabel.Caption := 'Collector acknowledged the scenario. Find its Trace ID in Grafana.'
  else
    StatusLabel.Caption := FSendThread.ErrorMessage;
  FreeAndNil(FSendThread);
  SetSending(False);
  if FClosePending then Close;
end;

end.
