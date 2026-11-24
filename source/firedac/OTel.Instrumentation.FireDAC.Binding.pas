unit OTel.Instrumentation.FireDAC.Binding;

interface

uses
  System.Classes, FireDAC.Comp.Client, OTel.Api, OTel.Instrumentation.Database.Contracts;

type
  IOTelFireDACInstrumentation = interface
    ['{3D2C9357-2210-4B20-83B2-F003014F807D}']
    procedure Bind(Client: TOTelTraceClient);
    procedure Detach;
    function BeginOperation(Subject: TFDAdaptedDataSet; const FallbackName: string;
      Bypass: Boolean): IOTelDatabaseOperation;
  end;

  TOTelFireDACInstrumentation = class(TComponent, IOTelFireDACInstrumentation)
  strict private
    FRecorder: IOTelDatabaseRecorder;
    function GetTracer: TOTelTracer;
    function GetDuration: TOTelHistogram;
  public
    destructor Destroy; override;
    // Bind or detach while the data module is idle. The host owns the client.
    procedure Bind(Client: TOTelTraceClient);
    procedure Detach;
    function BeginOperation(Subject: TFDAdaptedDataSet; const FallbackName: string;
      Bypass: Boolean): IOTelDatabaseOperation;
    property Tracer: TOTelTracer read GetTracer;
    property Duration: TOTelHistogram read GetDuration;
  end;

  IOTelFireDACDataSet = interface
    ['{318E2DEB-2D90-48AF-AA84-F64BB43CF195}']
    function GetInstrumentation: TOTelFireDACInstrumentation;
    procedure SetInstrumentation(Value: TOTelFireDACInstrumentation);
    property Instrumentation: TOTelFireDACInstrumentation read GetInstrumentation write SetInstrumentation;
  end;

implementation

uses
  System.SysUtils, FireDAC.Stan.Intf, OTel.Instrumentation.Database.Recorder,
  OTel.Instrumentation.FireDAC.Operation;

destructor TOTelFireDACInstrumentation.Destroy;
begin
  Detach;
  inherited;
end;

procedure TOTelFireDACInstrumentation.Bind(Client: TOTelTraceClient);
var
  Recorder: IOTelDatabaseRecorder;
begin
  if (Client = nil) or (csDesigning in ComponentState) then
  begin
    Detach;
    Exit;
  end;
  Recorder := TOTelDatabaseRecorder.Create(Client, 'OTel4D.FireDAC');
  FRecorder := Recorder;
end;

procedure TOTelFireDACInstrumentation.Detach;
begin
  FRecorder := nil;
end;

function TOTelFireDACInstrumentation.GetTracer: TOTelTracer;
begin
  Result := nil;
  if Assigned(FRecorder) then Result := FRecorder.GetTracer;
end;

function TOTelFireDACInstrumentation.GetDuration: TOTelHistogram;
begin
  Result := nil;
  if Assigned(FRecorder) then Result := FRecorder.GetDuration;
end;

function TOTelFireDACInstrumentation.BeginOperation(Subject: TFDAdaptedDataSet;
  const FallbackName: string; Bypass: Boolean): IOTelDatabaseOperation;
begin
  Result := nil;
  if Bypass or (Subject = nil) or not Assigned(FRecorder) then Exit;
  try
    if (Subject.ComponentState * [csDesigning, csLoading, csDestroying] <> []) or
       (Subject.ResourceOptions.CmdExecMode <> amBlocking) then Exit;
    Result := FRecorder.BeginOperation(FallbackName, TFireDACOperationMetadata.Create(Subject));
  except
    on E: Exception do Result := nil; // Let the original FireDAC call proceed.
  end;
end;

initialization
  RegisterClass(TOTelFireDACInstrumentation);

finalization
  UnRegisterClass(TOTelFireDACInstrumentation);

end.
