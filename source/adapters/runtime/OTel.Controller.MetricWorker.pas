unit OTel.Controller.MetricWorker;

interface

uses
  System.Generics.Collections, OTel.Application.Ports, OTel.Model.Dto.Metric, OTel.Runtime.Contracts;

type
  TMetricWorker = class(TInterfacedObject, IOTelWorkerTask)
  strict private
    FClock: IOTelClock;
    FStore: IOTelMetricAggregation;
    FExporter: IOTelExporter<TOTelMetricPoint>;
    FInterval: Cardinal;
    procedure Deliver(Points: TObjectList<TOTelMetricPoint>; Revision: Int64);
    procedure Execute;
  public
    constructor Create(const Store: IOTelMetricAggregation; const Exporter: IOTelExporter<TOTelMetricPoint>;
      const Clock: IOTelClock; IntervalMs: Integer);
  end;

implementation

uses
  System.SysUtils;

constructor TMetricWorker.Create(const Store: IOTelMetricAggregation;
  const Exporter: IOTelExporter<TOTelMetricPoint>; const Clock: IOTelClock; IntervalMs: Integer);
begin
  inherited Create;
  FStore := Store;
  FExporter := Exporter;
  FClock := Clock;
  FInterval := IntervalMs;
end;

procedure TMetricWorker.Deliver(Points: TObjectList<TOTelMetricPoint>; Revision: Int64);
var
  Rejected, Warnings: Integer;
begin
  try
    Rejected := FExporter.Export(Points, Warnings);
  except
    on E: Exception do
    begin
      Rejected := Points.Count;
      Warnings := 0;
    end;
  end;
  FStore.Complete(Revision, Rejected, Warnings);
end;

procedure TMetricWorker.Execute;
var
  Points: TObjectList<TOTelMetricPoint>;
  NextTick: UInt64;
  Revision: Int64;
begin
  NextTick := FClock.MonotonicMs + FInterval;
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
