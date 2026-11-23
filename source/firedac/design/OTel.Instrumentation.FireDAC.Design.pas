unit OTel.Instrumentation.FireDAC.Design;

interface

implementation

uses
  System.Classes, OTel.Instrumentation.FireDAC;

type
  TFireDACComponentRegistration = class
  public
    class procedure Install; static;
  end;

class procedure TFireDACComponentRegistration.Install;
begin
  RegisterComponents('OTel4D', [TOTelFireDACInstrumentation, TFDOtelQuery, TFDOtelStoredProc]);
end;

initialization
  TFireDACComponentRegistration.Install;

end.
