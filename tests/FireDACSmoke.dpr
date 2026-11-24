program FireDACSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client,
  FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.Stan.Pool, FireDAC.DApt,
  FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.FB, FireDAC.ConsoleUI.Wait,
  OTel.Api,
  FireDACFixture in 'FireDACFixture.pas' {DatabaseFixture: TDataModule};

type
  TFireDACSmoke = class
  strict private
    class procedure BusinessWorkflow(Client: TOTelTraceClient; const Name: string); static;
    class procedure SQLite(Client: TOTelTraceClient); static;
  public
    class procedure Run; static;
  end;

class procedure TFireDACSmoke.BusinessWorkflow(Client: TOTelTraceClient; const Name: string);
var
  Fixture: TDatabaseFixture;
  Tracer: TOTelTracer;
  Logger: TOTelLogger;
  Span: TOTelSpan;
begin
  Fixture := TDatabaseFixture.Create(nil);
  try
    Tracer := Client.GetTracer('orders.business');
    try
      Logger := Client.GetLogger('orders.business');
      try
        Span := Tracer.StartSpan(Name);
        try
          Span.WithContext(
            procedure
            begin
              Fixture.RunSQLite(Client, True);
              Logger.Emit(llInfo, 'database workflow completed');
            end);
        finally
          Span.Free;
        end;
      finally
        Logger.Free;
      end;
    finally
      Tracer.Free;
    end;
  finally
    Fixture.Free;
  end;
end;

class procedure TFireDACSmoke.SQLite(Client: TOTelTraceClient);
const
  Unsampled = '00-0123456789abcdef0123456789abcdef-0123456789abcdef-00';
var
  First, Second: TThread;
  Fixture: TDatabaseFixture;
begin
  First := TThread.CreateAnonymousThread(procedure begin BusinessWorkflow(Client, 'orders.first'); end);
  First.FreeOnTerminate := False;
  Second := nil;
  try
    Second := TThread.CreateAnonymousThread(procedure begin BusinessWorkflow(Client, 'orders.second'); end);
    Second.FreeOnTerminate := False;
    First.Start;
    Second.Start;
    First.WaitFor;
    Second.WaitFor;
    if Assigned(First.FatalException) then raise Exception.Create(Exception(First.FatalException).Message);
    if Assigned(Second.FatalException) then raise Exception.Create(Exception(Second.FatalException).Message);
  finally
    Second.Free;
    First.Free;
  end;
  Fixture := TDatabaseFixture.Create(nil);
  try
    TOTelTraceContext.WithContext(Unsampled, '', procedure begin Fixture.RunSQLite(Client, False); end);
  finally
    Fixture.Free;
  end;
end;

class procedure TFireDACSmoke.Run;
var
  Client: TOTelTraceClient;
  Fixture: TDatabaseFixture;
  Delivered: Boolean;
begin
  FDManager.Active := True;
  Client := TOTel.Open;
  try
    if ParamStr(1) = 'firebird' then
    begin
      Fixture := TDatabaseFixture.Create(nil);
      try
        Fixture.RunFirebird(Client, ParamStr(2), ParamStr(3));
      finally
        Fixture.Free;
      end;
    end
    else
      SQLite(Client);
    Delivered := Client.Shutdown(15000);
    Writeln('database operations passed, delivered=', Ord(Delivered));
  finally
    Client.Free;
  end;
end;

begin
  try
    TFireDACSmoke.Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ' - ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
