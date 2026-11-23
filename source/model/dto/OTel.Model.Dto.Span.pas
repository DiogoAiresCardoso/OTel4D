unit OTel.Model.Dto.Span;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Model.Dto.Telemetry;

type
  TOTelSpanKind = (skInternal, skServer, skClient, skProducer, skConsumer);
  TOTelStatus = (ssUnset, ssOk, ssError);

  TOTelEvent = class
  public
    Name, ExceptionType, ExceptionMessage: string;
    TimeNanos: UInt64;
  end;

  TOTelSpanData = class
  public
    TraceId, SpanId, ParentId, TraceState, Name, ScopeName, ScopeVersion: string;
    Flags: Cardinal;
    Kind: TOTelSpanKind;
    Status: TOTelStatus;
    StatusMessage: string;
    StartNanos, EndNanos: UInt64;
    Attributes: TDictionary<string, Variant>;
    Events: TObjectList<TOTelEvent>;
    DroppedAttributes, DroppedEvents: Cardinal;
    constructor Create;
    destructor Destroy; override;
  end;

  IOTelSpanSink = IOTelSink<TOTelSpanData>;

implementation

constructor TOTelSpanData.Create;
begin
  inherited;
  Attributes := TDictionary<string, Variant>.Create;
  Events := TObjectList<TOTelEvent>.Create(True);
end;

destructor TOTelSpanData.Destroy;
begin
  Events.Free;
  Attributes.Free;
  inherited;
end;

end.
