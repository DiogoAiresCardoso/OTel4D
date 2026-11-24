unit OTel.Instrumentation.FireDAC.Design;

interface

implementation

uses
  System.Classes, OTel.Instrumentation.FireDAC;

type
  IFireDACComponentRegistration = interface
    procedure Install;
  end;

  TFireDACComponentRegistration = class(TInterfacedObject, IFireDACComponentRegistration)
  public
    procedure Install;
  end;

procedure TFireDACComponentRegistration.Install;
begin
  RegisterComponents('OTel4D', [TOTelFireDACInstrumentation, TFDOtelQuery, TFDOtelStoredProc]);
end;

var
  Registration: IFireDACComponentRegistration;

initialization
  Registration := TFireDACComponentRegistration.Create;
  Registration.Install;
  Registration := nil;

end.
