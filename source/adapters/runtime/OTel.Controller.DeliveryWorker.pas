unit OTel.Controller.DeliveryWorker;

interface

uses
  OTel.Application.Ports, OTel.Runtime.Contracts;

type
  TDeliveryWorker<T: class> = class(TInterfacedObject, IOTelWorkerTask)
  strict private
    FQueue: IOTelBatchQueue<T>;
    FExporter: IOTelExporter<T>;
    procedure Execute;
  public
    constructor Create(const Queue: IOTelBatchQueue<T>; const Exporter: IOTelExporter<T>);
  end;

implementation

uses
  System.SysUtils, System.Generics.Collections;

constructor TDeliveryWorker<T>.Create(const Queue: IOTelBatchQueue<T>; const Exporter: IOTelExporter<T>);
begin
  inherited Create;
  FQueue := Queue;
  FExporter := Exporter;
end;

procedure TDeliveryWorker<T>.Execute;
var
  Batch: TObjectList<T>;
  Rejected, Warnings: Integer;
begin
  try
    Batch := TObjectList<T>.Create(True);
    try
      while FQueue.TakeBatch(Batch) do
      begin
        try
          Rejected := FExporter.Export(Batch, Warnings);
        except
          on E: Exception do
          begin
            Warnings := 0;
            Rejected := Batch.Count;
          end;
        end;
        FQueue.Complete(Batch.Count, Rejected, Warnings);
        Batch.Clear;
      end;
    finally
      Batch.Free;
    end;
  finally
    FQueue.Abandon;
  end;
end;

end.
