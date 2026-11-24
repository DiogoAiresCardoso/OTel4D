unit OTel.Model.Service.TraceContext;

interface

uses
  System.SysUtils;

type
  TOTelTraceContext = class
  strict private
    FTraceParent, FTraceState: string;
  public
    class function ValidParent(const Value: string): Boolean; static;
    class function ValidState(const Value: string): string; static;
    class function NewId(Bytes: Integer): string; static;
    class function NowNanos: UInt64; static;
    class function CurrentParent: string; static;
    class function CurrentState: string; static;
    class procedure WithContext(const Parent, State: string; const Action: TProc); static;
  end;

implementation

uses
  OTel.Application.Ports, OTel.Domain.TraceHeaders, OTel.Windows.Clock;

var
  Headers: IOTelTraceHeaders;
  Clock: IOTelClock;

threadvar
  Current: TOTelTraceContext;

class function TOTelTraceContext.ValidParent(const Value: string): Boolean;
begin
  Result := Headers.ValidParent(Value);
end;

class function TOTelTraceContext.ValidState(const Value: string): string;
begin
  Result := Headers.ValidState(Value);
end;

class function TOTelTraceContext.NewId(Bytes: Integer): string;
var
  Id: TGUID;
  Hex: string;
begin
  if CreateGUID(Id) <> 0 then
    raise EInvalidOpException.Create('Cannot generate a span identifier.');
  Hex := LowerCase(GUIDToString(Id));
  Hex := StringReplace(Copy(Hex, 2, 36), '-', '', [rfReplaceAll]);
  Result := Copy(Hex, Length(Hex) - Bytes * 2 + 1, Bytes * 2);
end;

class function TOTelTraceContext.NowNanos: UInt64;
begin
  Result := Clock.UnixNanos;
end;

class function TOTelTraceContext.CurrentParent: string;
begin
  if Assigned(Current) then Result := Current.FTraceParent else Result := '';
end;

class function TOTelTraceContext.CurrentState: string;
begin
  if Assigned(Current) then Result := Current.FTraceState else Result := '';
end;

class procedure TOTelTraceContext.WithContext(const Parent, State: string; const Action: TProc);
var
  Previous, Scope: TOTelTraceContext;
begin
  if not Assigned(Action) then raise EArgumentNilException.Create('Action must be assigned.');
  if not ValidParent(Parent) then
  begin
    Action();
    Exit;
  end;
  Scope := TOTelTraceContext.Create;
  try
    Scope.FTraceParent := Parent;
    Scope.FTraceState := ValidState(State);
    Previous := Current;
    Current := Scope;
    try
      Action();
    finally
      Current := Previous;
    end;
  finally
    Scope.Free;
  end;
end;

initialization
  Headers := TOTelTraceHeaders.Create;
  Clock := TOTelWindowsClock.Create;

end.
