unit OTel.Instrumentation.FireDAC.Query;

interface

uses
  System.Classes, FireDAC.Comp.Client, OTel.Instrumentation.FireDAC.Binding;

type
  TFDOtelQuery = class(TFDQuery)
  strict private
    FInstrumentation: TOTelFireDACInstrumentation;
    procedure SetInstrumentation(Value: TOTelFireDACInstrumentation);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure OpenCursor(InfoQuery: Boolean); override;
  public
    procedure Execute(ATimes: Integer = 0; AOffset: Integer = 0); override;
  published
    property Instrumentation: TOTelFireDACInstrumentation read FInstrumentation write SetInstrumentation;
  end;

implementation

uses
  System.SysUtils, OTel.Instrumentation.FireDAC.Operation;

procedure TFDOtelQuery.SetInstrumentation(Value: TOTelFireDACInstrumentation);
begin
  if FInstrumentation = Value then Exit;
  if Assigned(FInstrumentation) then FInstrumentation.RemoveFreeNotification(Self);
  FInstrumentation := Value;
  if Assigned(FInstrumentation) then FInstrumentation.FreeNotification(Self);
end;

procedure TFDOtelQuery.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FInstrumentation) then FInstrumentation := nil;
end;

procedure TFDOtelQuery.OpenCursor(InfoQuery: Boolean);
var
  Operation: TDatabaseOperation;
begin
  Operation := TDatabaseOperation.Start(FInstrumentation, Self, 'OPEN', InfoQuery or (DataSetField <> nil) or LoadFromFileAtOpen);
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
    Operation.Free;
  end;
end;

procedure TFDOtelQuery.Execute(ATimes, AOffset: Integer);
var
  Operation: TDatabaseOperation;
begin
  Operation := TDatabaseOperation.Start(FInstrumentation, Self, 'EXECUTE', False);
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
    Operation.Free;
  end;
end;

initialization
  RegisterClass(TFDOtelQuery);

finalization
  UnRegisterClass(TFDOtelQuery);

end.
