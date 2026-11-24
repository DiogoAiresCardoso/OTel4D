unit OTel.Instrumentation.Database.Recorder;

interface

uses
  OTel.Api, OTel.Instrumentation.Database.Contracts;

type
  TOTelDatabaseRecorder = class(TInterfacedObject, IOTelDatabaseRecorder)
  strict private
    FTracer: TOTelTracer;
    FDuration: TOTelHistogram;
    function GetTracer: TOTelTracer;
    function GetDuration: TOTelHistogram;
    function BeginOperation(const FallbackName: string;
      const Metadata: IOTelDatabaseMetadata): IOTelDatabaseOperation;
  public
    // The caller owns the client. Store the recorder as an interface.
    constructor Create(Client: TOTelTraceClient; const ScopeName: string);
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils, OTel.Instrumentation.Database.Operation;

constructor TOTelDatabaseRecorder.Create(Client: TOTelTraceClient; const ScopeName: string);
var
  Meter: TOTelMeter;
begin
  inherited Create;
  if Client = nil then raise EArgumentNilException.Create('Client must be assigned.');
  FTracer := Client.GetTracer(ScopeName);
  Meter := Client.GetMeter(ScopeName);
  try
    FDuration := Meter.CreateHistogram('db.client.operation.duration', 's',
      'Duration of database client operations.',
      [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0]);
  finally
    Meter.Free;
  end;
end;

destructor TOTelDatabaseRecorder.Destroy;
begin
  FDuration.Free;
  FTracer.Free;
  inherited;
end;

function TOTelDatabaseRecorder.GetTracer: TOTelTracer;
begin
  Result := FTracer;
end;

function TOTelDatabaseRecorder.GetDuration: TOTelHistogram;
begin
  Result := FDuration;
end;

function TOTelDatabaseRecorder.BeginOperation(const FallbackName: string;
  const Metadata: IOTelDatabaseMetadata): IOTelDatabaseOperation;
begin
  Result := nil;
  try
    Result := TOTelDatabaseOperation.Create(Self, FallbackName, Metadata);
  except
    on E: Exception do ; // The application can proceed without telemetry.
  end;
end;

end.
