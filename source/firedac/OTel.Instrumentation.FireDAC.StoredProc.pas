unit OTel.Instrumentation.FireDAC.StoredProc;

interface

uses
  System.Classes, FireDAC.Comp.Client, OTel.Instrumentation.FireDAC.Binding;

type
  TFDOtelStoredProc = class(TFDStoredProc, IOTelFireDACDataSet)
  strict private
    FInstrumentation: TOTelFireDACInstrumentation;
    function GetInstrumentation: TOTelFireDACInstrumentation;
    procedure SetInstrumentation(Value: TOTelFireDACInstrumentation);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure OpenCursor(InfoQuery: Boolean); override;
  public
    procedure Execute(ATimes: Integer = 0; AOffset: Integer = 0); override;
  published
    property Instrumentation: TOTelFireDACInstrumentation read GetInstrumentation write SetInstrumentation;
  end;

implementation

uses
  System.SysUtils, OTel.Instrumentation.Database.Contracts;

function TFDOtelStoredProc.GetInstrumentation: TOTelFireDACInstrumentation;
begin
  Result := FInstrumentation;
end;

procedure TFDOtelStoredProc.SetInstrumentation(Value: TOTelFireDACInstrumentation);
begin
  if FInstrumentation = Value then Exit;
  if Assigned(FInstrumentation) then FInstrumentation.RemoveFreeNotification(Self);
  FInstrumentation := Value;
  if Assigned(FInstrumentation) then FInstrumentation.FreeNotification(Self);
end;

procedure TFDOtelStoredProc.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FInstrumentation) then FInstrumentation := nil;
end;

procedure TFDOtelStoredProc.OpenCursor(InfoQuery: Boolean);
var
  Operation: IOTelDatabaseOperation;
begin
  if Assigned(FInstrumentation) then
    Operation := FInstrumentation.BeginOperation(Self, 'CALL',
      InfoQuery or (DataSetField <> nil) or LoadFromFileAtOpen);
  try
    try
      inherited OpenCursor(InfoQuery);
    except
      on E: Exception do
      begin
        if Assigned(Operation) then Operation.Failed(E);
        raise;
      end;
    end;
  finally
    if Assigned(Operation) then Operation.Finish;
  end;
end;

procedure TFDOtelStoredProc.Execute(ATimes, AOffset: Integer);
var
  Operation: IOTelDatabaseOperation;
begin
  if Assigned(FInstrumentation) then
    Operation := FInstrumentation.BeginOperation(Self, 'CALL', False);
  try
    try
      inherited Execute(ATimes, AOffset);
    except
      on E: Exception do
      begin
        if Assigned(Operation) then Operation.Failed(E);
        raise;
      end;
    end;
  finally
    if Assigned(Operation) then Operation.Finish;
  end;
end;

initialization
  RegisterClass(TFDOtelStoredProc);

finalization
  UnRegisterClass(TFDOtelStoredProc);

end.
