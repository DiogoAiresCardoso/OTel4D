unit OTel.Application.Ports;

interface

uses
  System.Generics.Collections, OTel.Model.Dto.Telemetry, OTel.Model.Dto.Metric,
  OTel.Model.Dto.Span, OTel.Model.Dto.Log, OTel.Model.Dto.Configuration;

type
  IOTelConfigurationSource = interface
    procedure ReadInto(const Options: TOTelOptions);
  end;

  IOTelEndpointResolver = interface
    function Render(const Options: TOTelOptions): string;
    function RenderSignal(const BaseUrl, SignalUrl, Suffix: string): string;
  end;

  IOTelConfigurationPolicy = interface
    procedure ApplyOverridesAndDefaults(const Options, Overrides: TOTelOptions;
      SkipDisabledExport: Boolean = False);
  end;

  IOTelConfigurationResolver = interface
    function Resolve(const Overrides: TOTelOptions; ForClient: Boolean): TOTelConfiguration;
  end;

  IOTelClock = interface
    function MonotonicMs: UInt64;
    function UnixNanos: UInt64;
  end;

  IOTelExporter<T: class> = interface
    // Borrows the batch for this call. One worker owns each exporter.
    function Export(Batch: TObjectList<T>; out Warnings: Integer): Integer;
    procedure Cancel;
  end;

  IOTelBatchQueue<T: class> = interface(IOTelSink<T>)
    function TakeBatch(Batch: TObjectList<T>): Boolean;
    procedure Complete(Count, Rejected, Warnings: Integer);
    function RequestFlush: Int64;
    function WaitFor(Target: Int64; Deadline: UInt64): Boolean;
    procedure Close;
    procedure Abandon;
    function Dropped: Int64;
    function Rejected: Int64;
    function Warnings: Int64;
  end;

  IOTelMetricStore = interface
    function RegisterInstrument(const Scope, Version, Name, UnitName, Description: string;
      Kind: TOTelMetricKind; const Bounds: array of Double): TOTelMetricDefinition;
    procedure Measure(Definition: TOTelMetricDefinition; Increment: Int64; Measurement: Double;
      const Attributes: TOTelAttributes);
  end;

  IOTelMetricAggregation = interface(IOTelMetricStore)
    function TakeSnapshot(IntervalMs: Cardinal; var NextTick: UInt64;
      out Points: TObjectList<TOTelMetricPoint>; out Revision: Int64): Boolean;
    procedure Complete(Revision, Rejected, Warnings: Int64);
    function RequestFlush: Int64;
    function WaitFor(Target: Int64; Deadline: UInt64): Boolean;
    procedure Close;
    procedure Stop;
    function Rejected: Int64;
    function Warnings: Int64;
    function Invalid: Int64;
  end;

  IOTelBatchSignal<T: class> = interface
    function Queue: IOTelBatchQueue<T>;
    procedure Close;
    function Drain(Deadline: UInt64): Boolean;
  end;

  IOTelMetricSignal = interface
    function Store: IOTelMetricAggregation;
    procedure Close;
    function Drain(Deadline: UInt64): Boolean;
  end;

  IOTelSignalFactory = interface
    function CreateTrace: IOTelBatchSignal<TOTelSpanData>;
    function CreateLogs: IOTelBatchSignal<TOTelLogData>;
    function CreateMetrics: IOTelMetricSignal;
  end;

  IOTelSession = interface
    function TraceSink: IOTelSink<TOTelSpanData>;
    function LogSink: IOTelSink<TOTelLogData>;
    function Metrics: IOTelMetricStore;
    function ForceFlush(TimeoutMs: Cardinal): Boolean;
    function Shutdown(TimeoutMs: Cardinal): Boolean;
    function DroppedSpans: Int64;
    function RejectedSpans: Int64;
    function DeliveryWarnings: Int64;
    function DroppedLogs: Int64;
    function RejectedLogs: Int64;
    function LogDeliveryWarnings: Int64;
    function RejectedMetricPoints: Int64;
    function MetricDeliveryWarnings: Int64;
    function InvalidMetricMeasurements: Int64;
  end;

implementation

end.
