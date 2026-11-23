unit FireDACFixture;

interface

uses
  System.Classes, Data.DB, FireDAC.Comp.Client, OTel.Api, OTel.Instrumentation.FireDAC;

type
  TDatabaseFixture = class(TDataModule)
    Connection: TFDConnection;
    Instrumentation: TOTelFireDACInstrumentation;
    Query: TFDOtelQuery;
    QueryAmount: TIntegerField;
    Proc: TFDOtelStoredProc;
    procedure QueryAfterOpen(DataSet: TDataSet);
  strict private
    FOpened: Integer;
  public
    procedure RunSQLite(Client: TOTelTraceClient; ExerciseFailure: Boolean);
    procedure RunFirebird(Client: TOTelTraceClient; const Database, LibraryPath: string);
  end;

implementation

uses
  System.SysUtils, FireDAC.Stan.Error, FireDAC.Stan.Param, FireDAC.Phys.FB;

{$R *.dfm}

procedure TDatabaseFixture.QueryAfterOpen(DataSet: TDataSet);
begin
  Inc(FOpened);
end;

procedure TDatabaseFixture.RunSQLite(Client: TOTelTraceClient; ExerciseFailure: Boolean);
begin
  if (Query.Instrumentation <> Instrumentation) or (Query.Connection <> Connection) or
     (QueryAmount.DataSet <> Query) or not Assigned(Query.AfterOpen) then
    raise Exception.Create('The migrated DFM lost a component reference, persistent field or event.');
  Instrumentation.Bind(Client);
  Connection.Params.Values['DriverID'] := 'SQLite';
  Connection.Params.Values['Database'] := ':memory:';
  Connection.Open;
  Connection.ExecSQL('create table fixture(amount integer, note varchar(30))');
  Query.SQL.Text := 'insert into fixture(amount, note) values (:amount, :note)';
  Query.ParamByName('amount').AsInteger := 19;
  Query.ParamByName('note').AsString := 'sensitive-parameter-fixture';
  Query.ExecSQL;
  Query.SQL.Text := 'select amount from fixture';
  try
    Query.Open;
    if (QueryAmount.AsInteger <> 19) or (FOpened <> 1) then
      raise Exception.Create('Instrumentation changed the dataset result or event count.');
  finally
    Query.Close;
  end;
  if ExerciseFailure then
  begin
    Query.SQL.Text := 'delete from sensitive-missing-table-fixture';
    try
      Query.ExecSQL;
      raise Exception.Create('The database exception was swallowed.');
    except
      on E: EFDDBEngineException do
        if E.Message = '' then raise;
    end;
  end;
end;

procedure TDatabaseFixture.RunFirebird(Client: TOTelTraceClient; const Database, LibraryPath: string);
var
  Driver: TFDPhysFBDriverLink;
begin
  if FileExists(Database) then raise Exception.Create('Use an unused path for the Firebird fixture.');
  Driver := TFDPhysFBDriverLink.Create(Self);
  Driver.VendorLib := LibraryPath;
  Connection.Params.Values['DriverID'] := 'FB';
  Connection.Params.Values['Database'] := Database;
  Connection.Params.Values['OpenMode'] := 'Create';
  Connection.Params.Values['User_Name'] := 'OTEL_FIXTURE';
  Connection.Open;
  Connection.ExecSQL('create procedure fixture_add (n integer) returns (v integer) as begin v = n + 1; end');
  Instrumentation.Bind(Client);
  Proc.StoredProcName := 'FIXTURE_ADD';
  Proc.Prepare;
  Proc.ParamByName('N').AsInteger := 41;
  Proc.ExecProc;
  if Proc.ParamByName('V').AsInteger <> 42 then
    raise Exception.Create('Instrumentation changed the stored procedure result.');
end;

end.
