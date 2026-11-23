---
name: verify-otlp-http
description: Verify OTel4D changes to trace encoding, HTTP delivery, OTLP responses or distributed context.
---

Identify the signal, wire format and endpoint rule affected. Use a canonical synthetic root and child with known IDs and times. For encoding, create the span through the real public API and decode the output independently. Compare parentage, resource, scope, flags and integer precision.

For transport, use a local receiver. Check POST, content type, body and path, including base URLs with a prefix and exact per-signal overrides. A prepared payload checks transport only. Exercise HTTP 200 with partial success without retry, a retryable 503 within a shared deadline, and a permanent 400. Include queue saturation or shutdown when touched. A live backend needs explicit authorization.

For propagation changes, inject a known W3C `traceparent` and `tracestate` into an inbound carrier and extract them through the public API. Start a child and inject its context into a fresh outbound carrier. Verify the trace ID, child span ID, flags and retained state. Exercise a malformed traceparent and confirm the previous context is restored after a worker finishes, including an exception path. [W3C Trace Context](https://www.w3.org/TR/trace-context/)

Report the layer tested, expected and actual outcomes, toolchain and missing coverage. Read the [testing standard](../../../docs/engineering/TESTING_STANDARDS.md) and [OTLP contract](https://opentelemetry.io/docs/specs/otlp/).
