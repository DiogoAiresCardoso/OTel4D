unit OTel.Controller.Trace;

interface

uses
  OTel.Model.Dto.Span, OTel.Controller.Span;

type
  TOTelSpan = OTel.Controller.Span.TOTelSpan;

  TOTelTracer = class
  strict private
    FSink: IOTelSpanSink;
    FName, FVersion: string;
  public
    constructor Create(const Sink: IOTelSpanSink; const Name, Version: string);
    // Each call returns a caller-owned span. Explicit parent headers come from a remote carrier.
    function StartSpan(const Name: string; Kind: TOTelSpanKind = skInternal): TOTelSpan; overload;
    function StartSpan(const Name: string; Kind: TOTelSpanKind;
      const TraceParent: string; const TraceState: string = ''): TOTelSpan; overload;
  end;

implementation

uses
  OTel.Model.Service.TraceContext;

constructor TOTelTracer.Create(const Sink: IOTelSpanSink; const Name, Version: string);
begin
  inherited Create;
  FSink := Sink;
  FName := Copy(Name, 1, 256);
  if FName = '' then FName := 'OTel4D';
  FVersion := Copy(Version, 1, 128);
end;

function TOTelTracer.StartSpan(const Name: string; Kind: TOTelSpanKind): TOTelSpan;
begin
  Result := TOTelSpan.Create(FSink, FName, FVersion, Name, TOTelTraceContext.CurrentParent,
    TOTelTraceContext.CurrentState, Kind, False);
end;

function TOTelTracer.StartSpan(const Name: string; Kind: TOTelSpanKind;
  const TraceParent, TraceState: string): TOTelSpan;
begin
  if not TOTelTraceContext.ValidParent(TraceParent) then Exit(StartSpan(Name, Kind));
  Result := TOTelSpan.Create(FSink, FName, FVersion, Name, TraceParent, TraceState, Kind, True);
end;

end.
