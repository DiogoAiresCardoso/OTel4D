# OTel4D implementation roadmap for logs, metrics and FireDAC

OTel4D sends all three signals from the Delphi process over OTLP/HTTP with binary Protobuf. The Delphi 10.2 Tokyo Win32 runtime retains MVC internally. Application code uses the public `OTel.Api` facade. FireDAC requires a separate runtime package and uses an optional Delphi IDE package.

The milestones below record the implementation sequence and its planned checks. For current behavior and the evidence available for each check, see [Implementation decisions](implementation.md#implementation-decisions) and [Verification](operations.md#verification).

## Milestone 1 — Structured logs

- Expose `Client.GetLogger(ScopeName, ScopeVersion)` and `Logger.Emit(Level, Body, Attributes, TimestampUnixNano)`. The logger snapshots typed attributes, source and observation timestamps, and any valid active trace IDs and flags before returning. Export valid correlation for an unsampled trace as well. Absent context leaves the IDs empty.
- Reuse endpoint validation, authentication, HTTP delivery and the OTLP acknowledgement parser. Export a binary `ExportLogsServiceRequest` using a separate worker and a bounded queue of 2,048 records with up to 128 per batch. Keep log drop, rejection and warning counters separate.
- Pass the decoder checks for severity, UTF-8, attribute ownership and sampled, unsampled and absent context. Verify retry, permanent failure and partial success with a loopback receiver. Forward a host logger through an application-owned adapter that selects and redacts fields before calling `Emit`. [Logs data model](https://opentelemetry.io/docs/specs/otel/logs/data-model/) · [OTLP specification](https://opentelemetry.io/docs/specs/otlp/)

## Milestone 2 — Cumulative metrics

- Expose `Client.GetMeter` with synchronous integer counters and up-down counters, and double histograms. Within a scope, reuse identical instrument definitions and reject incompatible duplicates. The typed set of attributes determines the aggregate. Reordering labels has no effect on the weight or identity of a series.
- Use cumulative OTLP sums and explicit-bucket histograms. Limit each client to 64 instruments, with 128 regular series and one overflow series per instrument. Use `otel.metric.overflow=true` for extra combinations. A periodic worker snapshots under the aggregation lock and sends after releasing it. It keeps the original cumulative aggregation even when the receiver rejects data. The reader defaults to 60 seconds and can be configured with `OTEL_METRIC_EXPORT_INTERVAL`.
- Extend flush and shutdown to cover all active signals under a shared wait deadline. Verify monotonic and signed sums, histogram bucket boundaries, timestamp progression, concurrency, partial rejection and bounded cardinality through a real Delphi consumer. [Metrics SDK](https://opentelemetry.io/docs/specs/otel/metrics/sdk/) · [OTLP metrics schema](https://github.com/open-telemetry/opentelemetry-proto/blob/main/opentelemetry/proto/metrics/v1/metrics.proto)

## Milestone 3 — FireDAC components

- Replace selected `TFDQuery` and `TFDStoredProc` instances with `TFDOtelQuery` and `TFDOtelStoredProc`, preserving DFM names, persistent fields and existing handlers. Bind the instrumentation component during application startup. Instrument the synchronous Tokyo virtual methods `OpenCursor` and `Execute` and leave application calls and FireDAC event ownership intact.
- Create a database client child span and record the same duration in `db.client.operation.duration`. Record the metric even when the trace is unsampled. Use allowlisted database system and operation labels and bounded exception types. Keep SQL, parameters, credentials, connection strings and raw database error text outside captured telemetry. [FireDAC execution modes](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Asynchronous_Execution_(FireDAC)) · [Database conventions](https://opentelemetry.io/docs/specs/semconv/db/database-spans/) · [Database duration metric](https://opentelemetry.io/docs/specs/semconv/db/database-metrics/#metric-dbclientoperationduration)
- Validate with one data module migrated first. Use SQLite for concurrent queries and a disposable Firebird database for procedure execution. Compare database results, errors, parentage and field/event streaming before deploying. Verify the three signals in an official Collector run. Confirm the design-time package and the migrated data module in the target IDE before distributing designer instructions as validated for that setup.

## Deployment and rollback

Configure signal-specific routes and export destinations. Enable logs and metrics through the library accessors or through the FireDAC integration. Disable individual export paths with `OTEL_LOGS_EXPORTER=none` or `OTEL_METRICS_EXPORTER=none`. To turn off FireDAC instrumentation, leave its component unbound or detach it while database work is idle. Stop and join producers, detach instrumentation, call `Shutdown` and release the client. See [telemetry configuration, API and migration](telemetry.md) and [delivery verification](operations.md#verification).
