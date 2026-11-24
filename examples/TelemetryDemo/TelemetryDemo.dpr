program TelemetryDemo;

uses
  Vcl.Forms,
  TelemetryDemo.Main in 'TelemetryDemo.Main.pas' {TelemetryDemoForm},
  TelemetryDemo.Session in 'TelemetryDemo.Session.pas',
  TelemetryDemo.SendThread in 'TelemetryDemo.SendThread.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TTelemetryDemoForm, TelemetryDemoForm);
  Application.Run;
end.
