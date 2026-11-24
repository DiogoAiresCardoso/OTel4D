# ADR 0003 — Separate telemetry policy from runtime adapters

**Status.** Accepted for the Tokyo Win32 runtime. This decision supersedes the internal MVC split in [ADR 0001](0001-library-mvc-and-otlp-http.md). Direct OTLP/HTTP and [optional database packages](0002-optional-database-adapters.md) remain the deployment model.

## Context

The original client resolved wire URLs, selected encoders, constructed WinHTTP transports and managed the three signal lifecycles. Delivery and time were concrete dependencies. Several public signal overrides were ignored, and invalid settings could surface after startup in a logger or FireDAC binding. A receiver with a 4 MiB limit could reject all 128 spans in a valid batch.

## Decision

Use ports and adapters with the Clean Architecture dependency rule. The bootstrap wires concrete implementations through interfaces. Preserve Delphi unit declarations, the caller-owned public handles in `OTel.Api`, and the streamed FireDAC components.

| Directory | Responsibility |
| --- | --- |
| `source/domain` | Signal data, attribute limits, metric definitions and W3C header validation. Entities and DTOs are classes with explicit ownership. |
| `source/application` | Startup settings precedence, metric aggregation, session lifecycle and delivery contracts. |
| `source/bootstrap` | Create the configuration resolver and one delivery factory per client. Inject configuration, clock and signal dependencies. |
| `source/adapters/api` | Keep `TOTel.Open`, tracer, spans, logger, meter and the configuration preview compatible. Capture owned DTOs and submit through the sink or measurement port. |
| `source/adapters/runtime` | Bounded FIFO, worker tasks and thread join. Request delivery through typed exporter interfaces. |
| `source/adapters/otlp` | Protobuf codecs, encoded byte limits, retry policy and HTTP authentication. |
| `source/adapters/configuration` and `source/adapters/windows` | Process environment, URL validation, Windows clock and thread-local context. |
| `source/adapters/database` and `source/firedac` | Shared operation recording and provider-specific hooks, DFM and IDE registration. |

~~~mermaid
flowchart LR
    Host["Delphi host"] --> Api["OTel.Api facade"]
    Api --> Bootstrap["Bootstrap"]
    Bootstrap --> App["Application ports and use cases"]
    Bootstrap --> Runtime["Buffer and Windows workers"]
    Bootstrap --> Otlp["OTLP exporter and HTTP transport"]
    Bootstrap --> Config["Environment and clock"]
    App --> Domain["Domain and DTOs"]
    Runtime --> App
    Otlp --> App
    Config --> App
    FireDAC["Optional FireDAC package"] --> Api
~~~

The arrows show source dependencies. During execution, the worker calls the export port and the injected OTLP adapter executes HTTP. Both `uses` clauses are checked for dependencies from domain or application to outer layers. Package and IDE project unit lists must agree.

## Design choices

- **Facade and Adapter.** Existing callers retain `TOTel.Open(Options)`, caller-owned handles and streamed FireDAC components. New service implementations are constructed into interfaces and receive dependencies at construction. RTL objects such as streams, lists and threads keep explicit ownership.
- **Inversion of dependencies.** `IOTelSession`, `IOTelSignalFactory`, `IOTelClock`, `IOTelExporter<T>` and the sink and store interfaces expose lifecycle and delivery seams. Typed DTOs cross the ports. WinHTTP statuses and serialized bytes stay in the OTLP adapter. The thread retains its task and the task retains the buffer and exporter until it exits.
- **Startup validation.** Read the environment once per open, merge explicit options and validate active exporters before starting delivery. Traces start at open, logs and metrics on first use. Disabled signals bypass their own exporter validation. The configuration preview reports merged settings separately from opening a client.
- **Bounded delivery.** Preserve one worker per active signal, up to 2,048 waiting records per trace or log queue and the default export intervals. Process up to 128 items at a time. Split an encoded batch over 4 MiB into ordered requests under the initial batch's deadline. An oversized single item is rejected locally. Repeat transient failures with the same request bytes.
- **Provider extension.** New integrations can take `IOTelDatabaseCapture` and capture through `IOTelDatabaseOperation`. The FireDAC compatibility binding exposes its borrowed handles. ADO and ODAC require their own tested optional packages. Scope names, FireDAC results and original exceptions stay compatible.

## Migration sequence and acceptance

1. Start from `develop`. Bring forward the optional FireDAC work and record API, DFM and OTLP behavior.
2. Reorganize the units by dependency layer and retain their Delphi names. Use instance methods and interface values for new application services and adapter composition.
3. Verify code-over-environment precedence, active exporter validation, exact routes, retry, partial success, large payloads, saturation and shutdown through package consumers.
4. Build the Win32 runtime, FireDAC runtime and design packages and the demo. Run the four scenarios in the local Docker lab. Compare trace hierarchy in Tempo, log severity and IDs in Loki, and cumulative values in Prometheus.
5. Review the change as a feature PR into `develop`. Rebuild BPL consumers. Direct source consumers update their [unit search path](../integration.md#link-an-existing-application).

Adding only transport injection in the MVC directories would reduce file moves while leaving layer ownership implicit. Splitting the runtime into mandatory BPLs would increase deployment and versioning costs. Keeping the base BPL intact preserves a single dependency for applications without database instrumentation.

[Usage](../integration.md) · [Source map](../source-map.md) · [Build and test instructions](../operations.md#verification) · [Local Grafana lab](../../infra/observability/README.md) · [Original ports and adapters article](https://alistair.cockburn.us/hexagonal-architecture) · [Clean Architecture dependency rule](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html#the-dependency-rule)
