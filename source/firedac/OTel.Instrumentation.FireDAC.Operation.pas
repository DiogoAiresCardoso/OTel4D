unit OTel.Instrumentation.FireDAC.Operation;

interface

uses
  System.SysUtils, System.Diagnostics, FireDAC.Comp.Client, OTel.Api,
  OTel.Instrumentation.FireDAC.Binding;

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

implementation

uses
  System.Classes, FireDAC.Stan.Intf, FireDAC.Phys.Intf;

class function TDatabaseOperation.Start(Instrumentation: TOTelFireDACInstrumentation;
  Subject: TFDAdaptedDataSet; const Fallback: string; Bypass: Boolean): TDatabaseOperation;
begin
  Result := nil;
  if Bypass or (Instrumentation = nil) then Exit;
  try
    if (Instrumentation.Tracer = nil) or
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
  FSpan := Instrumentation.Tracer.StartSpan(Fallback, skClient);
  FHistogram := Instrumentation.Duration;
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

end.
