# OpenTelemetry sources and OTel4D compatibility

The OpenTelemetry specification defines APIs and SDK behavior, the OTLP specification defines the exchange with the receiver, and Semantic Conventions define shared names and meanings. OTel4D is an independent implementation with its own Delphi API, limits, and lifecycle. The [language status table](https://opentelemetry.io/docs/languages/#status-and-releases) describes the upstream language implementations. The tables below tie the Delphi implementation to individual contracts.

## Specification and protocol sources

| Topic | What to look for | Official source |
| --- | --- | --- |
| Resource and scope | A resource describes the entity producing telemetry. A scope identifies the software that emitted a record. Use a stable service name and distinguish scopes by module or library. | [Resource SDK](https://opentelemetry.io/docs/specs/otel/resource/sdk/) · [Service attributes](https://opentelemetry.io/docs/specs/semconv/resource/service/) · [Instrumentation scope](https://opentelemetry.io/docs/specs/otel/common/instrumentation-scope/) |
| Trace lifecycle | Tracer, span and span context, span kinds, status, events, and explicit span end. | [Trace API](https://opentelemetry.io/docs/specs/otel/trace/api/) |
| Sampling and processing | Sampling decisions, parent-based delegation, batching, flush, and shutdown. | [Trace SDK](https://opentelemetry.io/docs/specs/otel/trace/sdk/) |
| Context and propagation | Active context within a process, extraction and injection using a carrier, and the cross-process wire format. | [Context API](https://opentelemetry.io/docs/specs/otel/context/) · [Propagators API](https://opentelemetry.io/docs/specs/otel/context/api-propagators/) · [W3C Trace Context](https://www.w3.org/TR/trace-context/) |
| Attributes and exceptions | Common attribute types, OTLP value mapping, span exception events, and error reporting. | [Common concepts](https://opentelemetry.io/docs/specs/otel/common/) · [Mapping to AnyValue](https://opentelemetry.io/docs/specs/otel/common/attribute-type-mapping/) · [Exceptions on spans](https://opentelemetry.io/docs/specs/otel/trace/exceptions/) · [Error handling conventions](https://opentelemetry.io/docs/specs/semconv/general/recording-errors/) |
| Structured logs | Event versus observation timestamp, severity, body, and optional trace correlation fields. The Logs API serves bridges to application logging frameworks. | [Logs data model](https://opentelemetry.io/docs/specs/otel/logs/data-model/) · [Logs API](https://opentelemetry.io/docs/specs/otel/logs/api/) · [Logs SDK](https://opentelemetry.io/docs/specs/otel/logs/sdk/) |
| Metrics | Instrument semantics, cumulative sums and histograms, reader/exporter behavior, and cardinality overflow. | [Metrics API](https://opentelemetry.io/docs/specs/otel/metrics/api/) · [Metrics SDK](https://opentelemetry.io/docs/specs/otel/metrics/sdk/) · [Metrics data model](https://opentelemetry.io/docs/specs/otel/metrics/data-model/) |
| Database instrumentation | Client span kind, SQL operation naming, database system identifiers, errors, and operation duration in seconds. | [Database spans](https://opentelemetry.io/docs/specs/semconv/db/database-spans/) · [SQL spans](https://opentelemetry.io/docs/specs/semconv/db/sql/) · [Database metrics](https://opentelemetry.io/docs/specs/semconv/db/database-metrics/) |
| Exporter configuration | Base versus exact signal routes, encoding choices, timeout, header syntax, and retry behavior. | [OTLP exporter](https://opentelemetry.io/docs/specs/otel/protocol/exporter/) · [SDK environment variables](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/) |
| Transport and schema | OTLP POST, media types, success and partial success, retryable status codes, and canonical wire fields. | [OTLP specification](https://opentelemetry.io/docs/specs/otlp/) · [Canonical .proto schemas](https://github.com/open-telemetry/opentelemetry-proto/tree/main/opentelemetry/proto) |
| Collector | The receiver accepts OTLP. The service pipeline connects receivers, processors, and exporters. | [Collector configuration](https://opentelemetry.io/docs/collector/configuration/) · [Collector troubleshooting](https://opentelemetry.io/docs/collector/troubleshooting/) |

The upstream Git repositories contain the revision history and original Markdown or protocol definitions. Use them when a published page explains a behavior but a change needs the exact source. [OpenTelemetry specification](https://github.com/open-telemetry/opentelemetry-specification) · [Semantic conventions](https://github.com/open-telemetry/semantic-conventions) · [OTLP schemas](https://github.com/open-telemetry/opentelemetry-proto) · [Collector](https://github.com/open-telemetry/opentelemetry-collector) · [OpenTelemetry website and language guides](https://github.com/open-telemetry/opentelemetry.io)

## What the Delphi implementation covers

| Contract | OTel4D behavior and scope |
| --- | --- |
| OTLP/HTTP | Binary Protobuf for traces, logs, and metrics. HTTP/JSON, gRPC, gzip requests, profiles, and persistent queues are outside the current runtime. |
| Exporter configuration | Base and exact per-signal HTTP(S) endpoints, custom headers, and timeouts. OTel4D uses Windows certificate trust and exposes no exporter options for custom certificates, mTLS, compression, or request-size limits. See the [supported options](integration.md#configuration-reference) and [signal settings](telemetry.md#configure-the-signals). |
| SDK configuration | Supports a service name, global disable switch, individual log and metric disable switches, and a periodic metric interval. The broader upstream environment-variable inventory, including `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_TRACES_EXPORTER`, sampler variables, and processor limits, has no binding here. |
| Traces and propagation | Manual instrumentation, W3C trace context, sampled roots, inheritance of the parent sampled bit, and native scope restoration for synchronous Delphi code. Span links, baggage, selectable samplers, and implicit task context propagation are outside the current API. |
| Resource and values | Every signal exports `service.name` and scope metadata. Application attributes cover string, signed 64-bit integer, Boolean, and double. Scope attributes, resource detectors, and compound values are outside the current API. |
| Logs | String body, typed attributes, six severity levels, two timestamps, and optional trace correlation. Use `Emit` directly or provide a bridge for the host logger. |
| Metrics | Synchronous cumulative integer counters and up-down counters, plus double explicit-bucket histograms. The API has no views, selectable or delta temporality, asynchronous instruments, gauges, or exemplars. |
| FireDAC | Components use selected database conventions for blocking calls and apply local privacy and cardinality rules. Check the documented operation boundaries before comparing results with a language agent or a broader database integration. |
| Assurance | The checked-in fixtures verify feature-level compatibility with the wire schema and exercise the Collector. They cover a narrower scope than an upstream SDK conformance suite. |

For an implementation choice and its rationale, see [Implementation and decisions](implementation.md). For the corresponding Delphi calls in an existing OpenTelemetry example, see [Language-to-Delphi guide](delphi-crosswalk.md).

## Upstream documentation

The OpenTelemetry website groups first-party language implementations under Language APIs & SDKs and points independent implementations to its community listings. Follow the current upstream status when proposing a listing. [Other languages](https://opentelemetry.io/docs/languages/other/) · [Registry contribution status](https://opentelemetry.io/ecosystem/registry/adding/) · [Website contributions](https://opentelemetry.io/docs/contributing/)
