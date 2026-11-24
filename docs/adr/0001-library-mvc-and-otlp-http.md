# ADR 0001 — Keep MVC inside the library and send OTLP directly over HTTP

**Status.** Accepted. Manual tracing and direct OTLP/HTTP Protobuf delivery are implemented for Delphi 10.2 Tokyo Win32. The first runtime was exercised against the official OpenTelemetry Collector. [Implementation and coverage](../implementation.md) · [Verification](../operations.md#verification)

**Context.** Delphi desktop, console and service applications need one client API. The consumer chooses the service identity, endpoint and authentication. The owner selected MVC for the library itself.

**Decision.** The Model owns IDs, immutable context, sampling and span lifecycle. The View renders a completed batch into OTLP bytes and a content type. The capture Controller accepts manual or adapter events and queues immutable finished spans. The delivery Controller calls the View and sends the batch through HTTP transport in a worker inside the process. FireDAC and framework instrumentation are optional. The consumer can configure the library once and use supported automatic adapters.

The planned integration links OTel4D into the application and requires rebuilding the executable. Once enabled, a supported adapter can capture operations without adding span calls at every site. Document the bootstrap, supported frameworks and gaps before describing an adapter as automatic instrumentation.

**Alternatives.** Requiring a particular application framework would couple callers to one integration. A separate exporter process would change the requested deployment model. A design based around ports and adapters was considered before the owner chose MVC.

**Consequences.** The library must bound memory, coordinate shutdown and honor retry deadlines. Start with traces and HTTP/Protobuf. HTTP/JSON is a possible representation when required by a receiver. Test clock and parentage, decode a View payload independently and exercise delivery against a loopback receiver. A previous Win32 transport probe sent a prepared payload; that alone does not demonstrate a working encoder or backend interoperability. [OTLP specification](https://opentelemetry.io/docs/specs/otlp/)
