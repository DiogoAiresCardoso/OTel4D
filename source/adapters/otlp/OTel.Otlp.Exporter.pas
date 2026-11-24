unit OTel.Otlp.Exporter;

interface

uses
  System.SysUtils, System.Generics.Collections, OTel.Application.Ports, OTel.Transport.Contracts;

type
  IOTelBatchEncoder<T: class> = interface
    function Encode(const Service: string; Batch: TObjectList<T>; Offset, Count: Integer): TBytes;
  end;

  TOTelOtlpExporter<T: class> = class(TInterfacedObject, IOTelExporter<T>)
  strict private
    const MaxBatchItems = 128;
    const MaxRequestBytes = 4 * 1024 * 1024;
  strict private
    FTransport: IOTelRequestTransport;
    FEncoder: IOTelBatchEncoder<T>;
    FService: string;
    function ExportSlice(Batch: TObjectList<T>; Offset, Count: Integer; Deadline: UInt64;
      var Warnings: Integer): Integer;
    function Export(Batch: TObjectList<T>; out Warnings: Integer): Integer;
    procedure Cancel;
  public
    constructor Create(const Transport: IOTelRequestTransport; const Encoder: IOTelBatchEncoder<T>;
      const Service: string);
  end;

implementation

uses
  System.Math;


constructor TOTelOtlpExporter<T>.Create(const Transport: IOTelRequestTransport;
  const Encoder: IOTelBatchEncoder<T>; const Service: string);
begin
  inherited Create;
  FTransport := Transport;
  FEncoder := Encoder;
  FService := Service;
end;

function TOTelOtlpExporter<T>.Export(Batch: TObjectList<T>; out Warnings: Integer): Integer;
var
  Deadline: UInt64;
  Offset, Count: Integer;
begin
  Result := 0;
  Warnings := 0;
  Offset := 0;
  while Offset < Batch.Count do
  begin
    Deadline := FTransport.Deadline;
    Count := Min(MaxBatchItems, Batch.Count - Offset);
    Inc(Result, ExportSlice(Batch, Offset, Count, Deadline, Warnings));
    Inc(Offset, Count);
  end;
end;

function TOTelOtlpExporter<T>.ExportSlice(Batch: TObjectList<T>; Offset, Count: Integer;
  Deadline: UInt64; var Warnings: Integer): Integer;
var
  Payload: TBytes;
  Warning: Boolean;
  Half: Integer;
begin
  if Count = 0 then Exit(0);
  // Account per slice so an encoder or transport failure cannot double-count earlier deliveries.
  try
    Payload := FEncoder.Encode(FService, Batch, Offset, Count);
    if Length(Payload) <= MaxRequestBytes then
    begin
      Result := FTransport.Post(Payload, Count, Deadline, Warning);
      if Warning then Inc(Warnings);
      Exit;
    end;
  except
    on E: Exception do Exit(Count);
  end;

  if Count = 1 then Exit(1);
  Payload := nil;
  Half := Count div 2;
  Result := ExportSlice(Batch, Offset, Half, Deadline, Warnings);
  Inc(Result, ExportSlice(Batch, Offset + Half, Count - Half, Deadline, Warnings));
end;

procedure TOTelOtlpExporter<T>.Cancel;
begin
  FTransport.Cancel;
end;

end.
