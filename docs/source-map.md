# OTel4D source and verification map

Use this map to follow a behavior from the public API to the code that owns it and the checks that exercise it. See [Implementation and decisions](implementation.md) for the design rationale and [Operations](operations.md#verification) for the commands and prerequisites.

## Runtime entry and configuration

| Unit | Responsibility |
| --- | --- |
| [OTel.Api](../source/adapters/api/OTel.Api.pas) | Application facade. Exposes the public types and constants and opens a client from a resolved snapshot. |
| [OTel.Controller.Configuration](../source/adapters/api/OTel.Controller.Configuration.pas) | Coordinates environment reads, overrides, default resolution, and endpoint rendering. Distinguishes preview from a disabled runtime client. |
| [OTel.Model.Dao.Environment](../source/adapters/configuration/OTel.Model.Dao.Environment.pas) | Reads supported process variables, resolves signal-specific fallbacks, and parses timeouts and the metric interval. |
| [OTel.Model.Service.Configuration](../source/application/OTel.Model.Service.Configuration.pas) | Applies supplied values and defaults, including service identity, trace protocol, and trace endpoint precedence. |
| [OTel.Model.Dto.Options](../source/domain/OTel.Model.Dto.Options.pas) | Caller overrides. Uses unset values for fallback and tracks whether the disable flag was explicitly assigned. Owns the additional signal settings. |
| [OTel.Model.Dto.Configuration](../source/domain/OTel.Model.Dto.Configuration.pas) | Resolved client inputs with separately owned additional signal settings. |
| [OTel.Model.Dto.SignalSettings](../source/domain/OTel.Model.Dto.SignalSettings.pas) | Reusable additional signal fields and per-source override rules. |
| [OTel.Model.Dto.ConfigurationError](../source/domain/OTel.Model.Dto.ConfigurationError.pas) | Exception type shared by configuration and metric registration. |
| [OTel.View.TraceEndpoint](../source/adapters/configuration/OTel.View.TraceEndpoint.pas) | Validates HTTP(S) URLs, paths, authority, and escapes. Renders a base URL with a signal suffix or retains an exact endpoint. |
| [OTel.Controller.TraceClient](../source/adapters/api/OTel.Controller.TraceClient.pas) | Adapts caller-owned legacy handles to application session ports. |
| [OTel.Bootstrap](../source/bootstrap/OTel.Bootstrap.pas) | Creates the clock, signal factory, configuration resolver and session through interfaces. |
| [OTel.Application.Ports](../source/application/OTel.Application.Ports.pas) | Defines clock, source, session, buffer, store and exporter contracts. |
| [OTel.Application.Session](../source/application/OTel.Application.Session.pas) | Coordinates activation, flush, shutdown and counters. |

## Capture and aggregate

| Unit | Responsibility |
| --- | --- |
| [OTel.Controller.Trace](../source/adapters/api/OTel.Controller.Trace.pas) | Tracer scope metadata and selection of an explicit, current, or root span context. |
| [OTel.Controller.Span](../source/adapters/api/OTel.Controller.Span.pas) | Span creation, sampling, timing, attributes, events, status, and one-time transfer to the sink. |
| [OTel.Model.Service.TraceContext](../source/adapters/windows/OTel.Model.Service.TraceContext.pas) | ID generation, Windows epoch conversion, W3C validation, and thread-local scope restoration. |
| [OTel.Model.Dto.Span](../source/domain/OTel.Model.Dto.Span.pas) | Span kind and status enums, completed span data, attributes, event ownership, and span sink alias. |
| [OTel.Model.Dto.SpanEvent](../source/domain/OTel.Model.Dto.SpanEvent.pas) | Named event snapshot with time and optional exception fields. |
| [OTel.Controller.Logger](../source/adapters/api/OTel.Controller.Logger.pas) | Captures severity, body, timestamps, attributes, and trace context before handing the record to a sink. |
| [OTel.Model.Dto.Log](../source/domain/OTel.Model.Dto.Log.pas) | Log severity and owned record data. |
| [OTel.Model.Dto.Telemetry](../source/domain/OTel.Model.Dto.Telemetry.pas) | Typed attribute container and copy operation. Declares the reference-counted sink interface and its ownership contract. |
| [OTel.Controller.Meter](../source/adapters/api/OTel.Controller.Meter.pas) | Scoped factory for synchronous instruments. Provides default histogram bounds and an overload for explicit bounds. |
| [OTel.Controller.MetricInstrument](../source/adapters/api/OTel.Controller.MetricInstrument.pas) | Retains an aggregation store through its interface and routes handle measurements to the corresponding instrument definition. |
| [OTel.Controller.Counter](../source/adapters/api/OTel.Controller.Counter.pas) | Integer `Add` used by both monotonic counters and signed up-down counters. |
| [OTel.Controller.Histogram](../source/adapters/api/OTel.Controller.Histogram.pas) | Double `RecordValue` for explicit-bucket distributions. |
| [OTel.Model.Dto.MetricDefinition](../source/domain/OTel.Model.Dto.MetricDefinition.pas) | Metric kind, scope, identity, unit, description, and bucket definition. |
| [OTel.Model.Dto.Metric](../source/domain/OTel.Model.Dto.Metric.pas) | Point representation and copy of mutable aggregation for delivery. |
| [OTel.Model.Service.MetricSeries](../source/domain/OTel.Model.Service.MetricSeries.pas) | Owns one definition's attribute-keyed point set and overflow point. |
| [OTel.Model.Service.MetricStore](../source/application/OTel.Model.Service.MetricStore.pas) | Registration, typed key canonicalization, bounds, aggregation, snapshot revisions, and metric loss accounting. |

## Queue, encode, and send

| Unit | Responsibility |
| --- | --- |
| [OTel.Controller.SpanQueue](../source/adapters/runtime/OTel.Controller.SpanQueue.pas) | Generic bounded FIFO for traces and logs. Coordinates producers, scheduled batches, explicit flush, close, and counters. |
| [OTel.Controller.BatchedSignal](../source/adapters/runtime/OTel.Controller.BatchedSignal.pas) | Owns the queue, cancellation event, transport, and delivery thread for an active trace or log signal. |
| [OTel.Controller.DeliveryWorker](../source/adapters/runtime/OTel.Controller.DeliveryWorker.pas) | Passes each batch through the exporter port and releases owned records. |
| [OTel.Otlp.Exporter](../source/adapters/otlp/OTel.Otlp.Exporter.pas) | Encodes slices, bounds HTTP requests by bytes and accounts per-request acknowledgements. |
| [OTel.Controller.MetricReader](../source/adapters/runtime/OTel.Controller.MetricReader.pas) | Owns the store, cancellation event, transport, and metric worker. Coordinates closing and draining. |
| [OTel.Controller.MetricWorker](../source/adapters/runtime/OTel.Controller.MetricWorker.pas) | Collects periodic or requested snapshots, splits them into requests, and marks each revision complete. |
| [OTel.View.Protobuf](../source/adapters/otlp/OTel.View.Protobuf.pas) | Shared wire primitives and scalar attribute, resource, and identifier encoding. |
| [OTel.View.TraceProtobuf](../source/adapters/otlp/OTel.View.TraceProtobuf.pas) | Maps completed spans and events into the binary trace export request. |
| [OTel.View.LogProtobuf](../source/adapters/otlp/OTel.View.LogProtobuf.pas) | Maps captured records, severity, timestamps, and IDs into the binary log export request. |
| [OTel.View.MetricProtobuf](../source/adapters/otlp/OTel.View.MetricProtobuf.pas) | Maps cumulative integer sums and explicit-bucket histogram snapshots into the binary metric export request. |
| [OTel.View.ProtobufResponse](../source/adapters/otlp/OTel.View.ProtobufResponse.pas) | Reads the shared OTLP acknowledgement shape, including rejection count and a flag for a warning. |
| [OTel.Transport.Http](../source/adapters/otlp/OTel.Transport.Http.pas) | Validates headers, posts binary bodies, applies retry and cancellation rules, and interprets response outcomes. |
| [OTel.Transport.ResponseStream](../source/adapters/otlp/OTel.Transport.ResponseStream.pas) | Limits memory used while accepting a receiver's response body. |
| [OTel.Transport.ResponseLimit](../source/adapters/otlp/OTel.Transport.ResponseLimit.pas) | Internal exception reported when writing a response would exceed the cap. |

## Database adapter contracts

| Unit | Responsibility |
| --- | --- |
| [OTel.Instrumentation.Database.Contracts](../source/adapters/database/OTel.Instrumentation.Database.Contracts.pas) | Defines the provider metadata, operation, and recorder interfaces. |
| [OTel.Instrumentation.Database.Recorder](../source/adapters/database/OTel.Instrumentation.Database.Recorder.pas) | Owns the database tracer and duration instrument for a scope and starts operations through an instance. |
| [OTel.Instrumentation.Database.Operation](../source/adapters/database/OTel.Instrumentation.Database.Operation.pas) | Captures the span, duration, and error type. Retains its recorder until it finishes. |

## FireDAC

| Unit | Responsibility |
| --- | --- |
| [OTel.Instrumentation.FireDAC](../source/firedac/OTel.Instrumentation.FireDAC.pas) | Public aliases for the instrumentation component and the two migrated data-set classes. |
| [OTel.Instrumentation.FireDAC.Binding](../source/firedac/OTel.Instrumentation.FireDAC.Binding.pas) | Binds to an application-owned client, retains the shared recorder through an interface, and filters unsupported dataset modes before capture. |
| [OTel.Instrumentation.FireDAC.Query](../source/firedac/OTel.Instrumentation.FireDAC.Query.pas) | Instruments blocking query cursor opens and command execution while preserving FireDAC calls and exception flow. |
| [OTel.Instrumentation.FireDAC.StoredProc](../source/firedac/OTel.Instrumentation.FireDAC.StoredProc.pas) | Instruments the corresponding stored procedure paths through the same operation helper. |
| [OTel.Instrumentation.FireDAC.Operation](../source/firedac/OTel.Instrumentation.FireDAC.Operation.pas) | Implements the provider metadata interface and maps allowlisted database and operation labels from FireDAC. |
| [OTel.Instrumentation.FireDAC.Design](../source/firedac/design/OTel.Instrumentation.FireDAC.Design.pas) | Registers the components in the Delphi IDE. The runtime units separately register their classes for streaming. |

## Build, sample, and check

| Surface | Source and evidence |
| --- | --- |
| Delphi build and package boundaries | The [project group](../OTel4D.groupproj) and the core [DPK](../source/OTel4D.dpk) and [DPROJ](../source/OTel4D.dproj) describe the build. Optional [FireDAC runtime project](../source/firedac/OTel4DFireDAC.dproj) and [IDE project](../source/firedac/design/OTel4DFireDACDesign.dproj) isolate FireDAC and designer dependencies. |
| Minimum example | [FirstTrace.dpr](../examples/FirstTrace.dpr) exercises parentage, explicit lifetime, and the public API against the [Collector debug configuration](../examples/collector.yaml). |
| Programmatic configuration | [ConfiguredTelemetry.dpr](../examples/ConfiguredTelemetry.dpr) sets up a client in code and emits all three signals with a cumulative counter. |
| Existing host logger | [OTel.Example.LogBridge.pas](../examples/OTel.Example.LogBridge.pas) illustrates application-owned filtering and structured forwarding into OTel4D. |
| VCL demo | [Main form](../examples/TelemetryDemo/TelemetryDemo.Main.pas) and [DFM](../examples/TelemetryDemo/TelemetryDemo.Main.dfm) own the UI. [Send thread](../examples/TelemetryDemo/TelemetryDemo.SendThread.pas) handles off-UI execution. [Session](../examples/TelemetryDemo/TelemetryDemo.Session.pas) owns telemetry and the four business scenarios. |
| Local backend | The [Compose lab](../infra/observability/README.md) checks OTLP ingestion and querying the three signals. [Lab smoke](../infra/observability/tests/smoke.py) sends synthetic fixtures. [Demo verification](../infra/observability/tests/verify_delphi_demo.py) queries the data emitted by Delphi. |
| Configuration | The [Win32 configuration consumer](../tests/ConfigurationSmoke.dpr) checks the public API, setting precedence, ownership, and URL handling. |
| Traces | [Delphi consumer](../tests/TraceSmoke.dpr) and [independent Python decoder](../tests/verify_traces.py) check payloads, failures, and delivery boundaries through an HTTP receiver. |
| Logs and metrics | [Delphi consumer](../tests/TelemetrySmoke.dpr) and [independent Python decoder](../tests/verify_telemetry.py) check correlation, cumulative aggregation, limits, and independent delivery. |
| FireDAC | [Delphi consumer](../tests/FireDACSmoke.dpr), [migrated DFM](../tests/FireDACFixture.dfm), and [verifier](../tests/verify_firedac.py) exercise query results, errors, streaming, and optional Firebird and Collector integration. |
| Quality and distribution | [Repository checks](../tools/check_project.py) and [guardrail tests](../tests/test_guardrails.py) run in [CI](../.github/workflows/quality.yml). The [release workflow](../.github/workflows/release.yml) validates source tags. The [bundle builder](../tools/build-demo-bundle.ps1) builds the Win32 demo and local lab with the Delphi toolchain. |
