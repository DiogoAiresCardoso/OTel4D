unit OTel.Controller.Logger;

interface

uses
  OTel.Model.Dto.Log, OTel.Model.Dto.Telemetry;

type
  TOTelLogger = class
  strict private
    FSink: IOTelSink<TOTelLogData>;
    FScope, FVersion: string;
  public
    constructor Create(const Sink: IOTelSink<TOTelLogData>; const Scope, Version: string);
    procedure Emit(Level: TOTelLogLevel; const Body: string;
      const Attributes: TOTelAttributes = nil; TimestampUnixNano: UInt64 = 0);
  end;

implementation

uses
  System.SysUtils, OTel.Model.Service.TraceContext;

constructor TOTelLogger.Create(const Sink: IOTelSink<TOTelLogData>; const Scope, Version: string);
begin
  inherited Create;
  FSink := Sink;
  FScope := Copy(Scope, 1, 256);
  if FScope = '' then FScope := 'OTel4D';
  FVersion := Copy(Version, 1, 128);
end;

procedure TOTelLogger.Emit(Level: TOTelLogLevel; const Body: string;
  const Attributes: TOTelAttributes; TimestampUnixNano: UInt64);
var
  Data, Owned: TOTelLogData;
  Parent: string;
begin
  if not Assigned(FSink) then Exit;
  if not FSink.IsAccepting then Exit;
  Data := TOTelLogData.Create;
  try
    Data.Level := Level;
    Data.Scope := FScope;
    Data.Version := FVersion;
    Data.Body := Copy(Body, 1, 4096);
    if (Length(Body) > 4096) and (Data.Body[4096] >= #$D800) and (Data.Body[4096] <= #$DBFF) then
      SetLength(Data.Body, 4095);
    Data.ObservedTimestamp := TOTelTraceContext.NowNanos;
    Data.Timestamp := TimestampUnixNano;
    if Data.Timestamp = 0 then Data.Timestamp := Data.ObservedTimestamp;
    Parent := TOTelTraceContext.CurrentParent;
    if Parent <> '' then
    begin
      Data.TraceId := Copy(Parent, 4, 32);
      Data.SpanId := Copy(Parent, 37, 16);
      Data.Flags := StrToInt('$' + Copy(Parent, 54, 2));
    end;
    if Assigned(Attributes) then Data.Attributes := Attributes.Snapshot;
    Owned := Data;
    Data := nil;
    FSink.Submit(Owned);
  finally
    Data.Free;
  end;
end;

end.
