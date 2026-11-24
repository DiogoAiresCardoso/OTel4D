unit OTel.Model.Dto.Log;

interface

uses
  OTel.Model.Dto.Telemetry;

type
  TOTelLogLevel = (llTrace, llDebug, llInfo, llWarn, llError, llFatal);

  TOTelLogData = class
  public
    Scope, Version, Body, TraceId, SpanId: string;
    Level: TOTelLogLevel;
    Flags: Cardinal;
    Timestamp, ObservedTimestamp: UInt64;
    Attributes: TOTelAttributes;
    destructor Destroy; override;
  end;

implementation

destructor TOTelLogData.Destroy;
begin
  Attributes.Free;
  inherited;
end;

end.
