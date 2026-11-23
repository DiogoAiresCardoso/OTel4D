unit OTel.Instrumentation.FireDAC;

interface

uses
  System.Classes, FireDAC.Comp.Client, OTel.Api;

type
  TOTelFireDACInstrumentation = class(TComponent)
  private
    FTracer: TOTelTracer;
    FDuration: TOTelHistogram;
  public
    destructor Destroy; override;
    // Bind or detach while the data module is idle. The host owns the client.
    procedure Bind(Client: TOTelTraceClient);
    procedure Detach;
  end;

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

  TFDOtelStoredProc = class(TFDStoredProc)
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
  System.SysUtils, System.Diagnostics, FireDAC.Stan.Intf, FireDAC.Phys.Intf;

type
  TDatabaseOperation = class
  strict private
    FSubject: TFDAdaptedDataSet;
    FSpan: TOTelSpan;
    FHistogram: TOTelHistogram;
    FClock: TStopwatch;
    FFallback, FErrorType: string;
    class function SystemName(Command: TFDCustomCommand): string; static;
    class function OperationName(Command: TFDCustomCommand; const Fallback: string): string; static;
    procedure Finish;
  public
    constructor Create(Instrumentation: TOTelFireDACInstrumentation; Subject: TFDAdaptedDataSet;
      const Fallback: string);
    destructor Destroy; override;
    class function Start(Instrumentation: TOTelFireDACInstrumentation; Subject: TFDAdaptedDataSet;
      const Fallback: string; Bypass: Boolean): TDatabaseOperation; static;
    procedure Failed(const Error: Exception);
  end;

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

class function TDatabaseOperation.Start(Instrumentation: TOTelFireDACInstrumentation;
  Subject: TFDAdaptedDataSet; const Fallback: string; Bypass: Boolean): TDatabaseOperation;
begin
  Result := nil;
  if Bypass or (Instrumentation = nil) then Exit;
  try
    if (Instrumentation.FTracer = nil) or
       (Subject.ComponentState * [csDesigning, csLoading, csDestroying] <> []) or
       (Subject.ResourceOptions.CmdExecMode <> amBlocking) then Exit;
    Result := TDatabaseOperation.Create(Instrumentation, Subject, Fallback);
  except
    on E: Exception do Result := nil;
  end;
end;

constructor TDatabaseOperation.Create(Instrumentation: TOTelFireDACInstrumentation;
  Subject: TFDAdaptedDataSet; const Fallback: string);
begin
  inherited Create;
  FSubject := Subject;
  FFallback := Fallback;
  FClock := TStopwatch.StartNew;
  FSpan := Instrumentation.FTracer.StartSpan(Fallback, skClient);
  FHistogram := Instrumentation.FDuration;
end;

class function TDatabaseOperation.SystemName(Command: TFDCustomCommand): string;
var
  Connection: TFDCustomConnection;
begin
  Result := 'other_sql';
  if Command = nil then Exit;
  Connection := Command.Connection;
  if Connection = nil then Exit;
  case Connection.RDBMSKind of
    TFDRDBMSKinds.Firebird: Result := 'firebirdsql';
    TFDRDBMSKinds.SQLite: Result := 'sqlite';
    TFDRDBMSKinds.PostgreSQL: Result := 'postgresql';
    TFDRDBMSKinds.MSSQL: Result := 'microsoft.sql_server';
    TFDRDBMSKinds.Oracle: Result := 'oracle.db';
    TFDRDBMSKinds.MySQL: Result := 'mysql';
    TFDRDBMSKinds.Interbase: Result := 'interbase';
    TFDRDBMSKinds.DB2: Result := 'ibm.db2';
  end;
end;

class function TDatabaseOperation.OperationName(Command: TFDCustomCommand; const Fallback: string): string;
begin
  Result := Fallback;
  if Command = nil then Exit;
  case Command.CommandKind of
    skSelect, skSelectForLock, skSelectForUnLock: Result := 'SELECT';
    skInsert: Result := 'INSERT';
    skUpdate: Result := 'UPDATE';
    skDelete: Result := 'DELETE';
    skMerge: Result := 'MERGE';
    skStoredProc, skStoredProcWithCrs, skStoredProcNoCrs: Result := 'CALL';
  end;
end;

procedure TDatabaseOperation.Failed(const Error: Exception);
begin
  try
    FErrorType := Copy(Error.ClassName, 1, 128);
  except
    on E: Exception do ;
  end;
end;

procedure TDatabaseOperation.Finish;
var
  Labels: TOTelAttributes;
  Operation, Database: string;
  Duration: Double;
begin
  if FSpan = nil then Exit;
  FClock.Stop;
  Database := 'other_sql';
  Operation := FFallback;
  try
    Database := SystemName(FSubject.Command);
    Operation := OperationName(FSubject.Command, FFallback);
  except
    on E: Exception do ;
  end;
  FSpan.SetAttribute('db.system.name', Database);
  FSpan.SetAttribute('db.operation.name', Operation);
  if FErrorType <> '' then
  begin
    FSpan.SetAttribute('error.type', FErrorType);
    FSpan.SetStatus(ssError, 'Database operation failed');
  end;
  if FSpan.IsRecording then Duration := FSpan.FinishWithDuration / 1000000000
  else Duration := FClock.ElapsedTicks / TStopwatch.Frequency;
  if FHistogram = nil then Exit;
  Labels := TOTelAttributes.Create;
  try
    Labels.Put('db.system.name', Database);
    Labels.Put('db.operation.name', Operation);
    if FErrorType <> '' then Labels.Put('error.type', FErrorType);
    FHistogram.RecordValue(Duration, Labels);
  finally
    Labels.Free;
  end;
end;

destructor TDatabaseOperation.Destroy;
begin
  try
    try
      Finish;
    finally
      FSpan.Free;
    end;
  except
    // Instrumentation must preserve the inherited database result or exception.
    on E: Exception do ;
  end;
  inherited;
end;

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
  Operation: TDatabaseOperation;
begin
  Operation := TDatabaseOperation.Start(FInstrumentation, Self, 'CALL', InfoQuery or (DataSetField <> nil) or LoadFromFileAtOpen);
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

procedure TFDOtelStoredProc.Execute(ATimes, AOffset: Integer);
var
  Operation: TDatabaseOperation;
begin
  Operation := TDatabaseOperation.Start(FInstrumentation, Self, 'CALL', False);
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
  RegisterClasses([TOTelFireDACInstrumentation, TFDOtelQuery, TFDOtelStoredProc]);

finalization
  UnRegisterClasses([TOTelFireDACInstrumentation, TFDOtelQuery, TFDOtelStoredProc]);

end.
