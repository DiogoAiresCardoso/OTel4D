unit OTel.Instrumentation.FireDAC.Operation;

interface

uses
  FireDAC.Comp.Client, OTel.Instrumentation.Database.Contracts;

type
  TFireDACOperationMetadata = class(TInterfacedObject, IOTelDatabaseMetadata)
  strict private
    FSubject: TFDAdaptedDataSet;
    function ReadSystemName(Command: TFDCustomCommand; const DefaultName: string): string;
    function ReadOperationName(Command: TFDCustomCommand; const DefaultName: string): string;
    procedure ReadNames(var DatabaseName, OperationName: string);
  public
    // Borrows the dataset until the enclosing operation finishes.
    constructor Create(Subject: TFDAdaptedDataSet);
  end;

implementation

uses
  FireDAC.Stan.Intf, FireDAC.Phys.Intf;

constructor TFireDACOperationMetadata.Create(Subject: TFDAdaptedDataSet);
begin
  inherited Create;
  FSubject := Subject;
end;

procedure TFireDACOperationMetadata.ReadNames(var DatabaseName, OperationName: string);
var
  Command: TFDCustomCommand;
begin
  Command := FSubject.Command;
  if Command = nil then Exit;
  DatabaseName := ReadSystemName(Command, DatabaseName);
  OperationName := ReadOperationName(Command, OperationName);
end;

function TFireDACOperationMetadata.ReadSystemName(Command: TFDCustomCommand;
  const DefaultName: string): string;
var
  Connection: TFDCustomConnection;
begin
  Result := DefaultName;
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

function TFireDACOperationMetadata.ReadOperationName(Command: TFDCustomCommand;
  const DefaultName: string): string;
begin
  Result := DefaultName;
  case Command.CommandKind of
    skSelect, skSelectForLock, skSelectForUnLock: Result := 'SELECT';
    skInsert: Result := 'INSERT';
    skUpdate: Result := 'UPDATE';
    skDelete: Result := 'DELETE';
    skMerge: Result := 'MERGE';
    skStoredProc, skStoredProcWithCrs, skStoredProcNoCrs: Result := 'CALL';
  end;
end;

end.
