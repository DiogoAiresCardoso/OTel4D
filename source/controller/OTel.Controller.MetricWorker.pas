unit OTel.Controller.MetricWorker;

interface

uses
  System.Classes, System.Generics.Collections, OTel.Model.Service.MetricStore,
  OTel.Transport.Http, OTel.Model.Dto.Metric;

type
  TMetricWorker = class(TThread)
  strict private
    FStore: TOTelMetricStore;
    FTransport: TOTelHttpTransport;
    FInterval: Cardinal;
    FService: string;
    procedure Deliver(Points: TObjectList<TOTelMetricPoint>; Revision: Int64);
  protected
    procedure Execute; override;
  public
    constructor Create(Store: TOTelMetricStore; Transport: TOTelHttpTransport;
      IntervalMs: Integer; const Service: string);
  end;

implementation

uses
  System.SysUtils, System.Math, Winapi.Windows, OTel.View.MetricProtobuf;

constructor TMetricWorker.Create(Store: TOTelMetricStore; Transport: TOTelHttpTransport;
  IntervalMs: Integer; const Service: string);
begin
  inherited Create(True);
  FStore := Store;
  FTransport := Transport;
  FInterval := IntervalMs;
  FService := Service;
end;

procedure TMetricWorker.Deliver(Points: TObjectList<TOTelMetricPoint>; Revision: Int64);
const
  PointBatchSize = 128;
var
  Offset, Count, Rejected, Warnings: Integer;
  Warning: Boolean;
begin
  Rejected := 0;
  Warnings := 0;
  Offset := 0;
  while Offset < Points.Count do
  begin
    Count := Min(Points.Count - Offset, PointBatchSize);
    try
      Inc(Rejected, FTransport.Send(TOTelMetricProtobuf.Encode(FService, Points, Offset, Count), Count, Warning));
      if Warning then Inc(Warnings);
    except
      on E: Exception do Inc(Rejected, Count);
    end;
    Inc(Offset, Count);
  end;
  FStore.Complete(Revision, Rejected, Warnings);
end;

procedure TMetricWorker.Execute;
var
  Points: TObjectList<TOTelMetricPoint>;
  NextTick: UInt64;
  Revision: Int64;
begin
  if Terminated then Exit;
  NextTick := GetTickCount64 + FInterval;
  try
    while FStore.TakeSnapshot(FInterval, NextTick, Points, Revision) do
    try
      Deliver(Points, Revision);
    finally
      Points.Free;
    end;
  finally
    FStore.Stop;
  end;
end;

end.
