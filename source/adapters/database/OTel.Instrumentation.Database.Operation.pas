unit OTel.Instrumentation.Database.Operation;

interface

uses
  System.SysUtils, System.Diagnostics, OTel.Api, OTel.Instrumentation.Database.Contracts;

type
  TOTelDatabaseOperation = class(TInterfacedObject, IOTelDatabaseOperation)
  strict private
    FRecorder: IOTelDatabaseRecorder;
    FMetadata: IOTelDatabaseMetadata;
    FSpan: TOTelSpan;
    FClock: TStopwatch;
    FFallbackName, FErrorType: string;
    procedure Failed(const Error: Exception);
    procedure Finish;
    procedure RecordDuration(const DatabaseName, OperationName: string; Seconds: Double);
  public
    constructor Create(const Recorder: IOTelDatabaseRecorder; const FallbackName: string;
      const Metadata: IOTelDatabaseMetadata);
    destructor Destroy; override;
  end;

implementation

constructor TOTelDatabaseOperation.Create(const Recorder: IOTelDatabaseRecorder;
  const FallbackName: string; const Metadata: IOTelDatabaseMetadata);
begin
  inherited Create;
  FRecorder := Recorder;
  FMetadata := Metadata;
  FFallbackName := FallbackName;
  FClock := TStopwatch.StartNew;
  FSpan := FRecorder.GetTracer.StartSpan(FallbackName, skClient);
end;

destructor TOTelDatabaseOperation.Destroy;
begin
  Finish;
  inherited;
end;

procedure TOTelDatabaseOperation.Failed(const Error: Exception);
begin
  if (FSpan = nil) or (Error = nil) then Exit;
  try
    FErrorType := Copy(Error.ClassName, 1, 128);
  except
    on E: Exception do ; // Preserve the application's original exception.
  end;
end;

procedure TOTelDatabaseOperation.RecordDuration(const DatabaseName, OperationName: string;
  Seconds: Double);
var
  Labels: TOTelAttributes;
begin
  Labels := TOTelAttributes.Create;
  try
    Labels.Put('db.system.name', DatabaseName);
    Labels.Put('db.operation.name', OperationName);
    if FErrorType <> '' then Labels.Put('error.type', FErrorType);
    FRecorder.GetDuration.RecordValue(Seconds, Labels);
  finally
    Labels.Free;
  end;
end;

procedure TOTelDatabaseOperation.Finish;
var
  Span: TOTelSpan;
  DatabaseName, OperationName: string;
  Seconds: Double;
begin
  Span := FSpan;
  if Span = nil then Exit;
  FSpan := nil;
  try
    try
      FClock.Stop;
      DatabaseName := 'other_sql';
      OperationName := FFallbackName;
      if Assigned(FMetadata) then
        try
          FMetadata.ReadNames(DatabaseName, OperationName);
        except
          on E: Exception do ; // Keep the available metadata when a driver lookup fails.
        end;

      Span.SetAttribute('db.system.name', DatabaseName);
      Span.SetAttribute('db.operation.name', OperationName);
      if FErrorType <> '' then
      begin
        Span.SetAttribute('error.type', FErrorType);
        Span.SetStatus(ssError, 'Database operation failed');
      end;

      if Span.IsRecording then Seconds := Span.FinishWithDuration / 1000000000
      else Seconds := FClock.ElapsedTicks / TStopwatch.Frequency;
      if Assigned(FRecorder.GetDuration) then RecordDuration(DatabaseName, OperationName, Seconds);
    finally
      try
        Span.Free;
      finally
        FMetadata := nil;
        FRecorder := nil;
      end;
    end;
  except
    on E: Exception do ; // Instrumentation must preserve the inherited database result or exception.
  end;
end;

end.
