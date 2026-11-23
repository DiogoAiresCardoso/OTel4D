unit OTel.Controller.DeliveryWorker;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  OTel.Controller.SpanQueue, OTel.Transport.Http;

type
  TOTelBatchEncoder<T: class> = reference to function(const Service: string; Batch: TObjectList<T>): TBytes;

  TDeliveryWorker<T: class> = class(TThread)
  strict private
    FQueue: TOTelBatchQueue<T>;
    FTransport: TOTelHttpTransport;
    FService: string;
    FEncoder: TOTelBatchEncoder<T>;
  protected
    procedure Execute; override;
  public
    constructor Create(Queue: TOTelBatchQueue<T>; Transport: TOTelHttpTransport;
      const Service: string; const Encoder: TOTelBatchEncoder<T>);
  end;

implementation

constructor TDeliveryWorker<T>.Create(Queue: TOTelBatchQueue<T>; Transport: TOTelHttpTransport;
  const Service: string; const Encoder: TOTelBatchEncoder<T>);
begin
  inherited Create(True);
  FQueue := Queue;
  FTransport := Transport;
  FService := Service;
  FEncoder := Encoder;
end;

procedure TDeliveryWorker<T>.Execute;
var
  Batch: TObjectList<T>;
  Rejected: Integer;
  Warning: Boolean;
begin
  if Terminated then Exit;
  try
    Batch := TObjectList<T>.Create(True);
    try
      while FQueue.TakeBatch(Batch) do
      begin
        try
          Rejected := FTransport.Send(FEncoder(FService, Batch), Batch.Count, Warning);
        except
          on E: Exception do
          begin
            Warning := False;
            Rejected := Batch.Count;
          end;
        end;
        FQueue.Complete(Batch.Count, Rejected, Warning);
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
