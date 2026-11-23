# Operate and verify Delphi trace delivery

## What a successful export means

The worker sends an HTTP POST with `Content-Type: application/x-protobuf` and `Accept: application/x-protobuf`. The body is one binary `ExportTraceServiceRequest`. It accepts a successful OTLP acknowledgement from the receiver. Indexing, retention and availability in a backend UI depend on the receiver's downstream pipeline. The Collector's `debug` exporter is useful for independently seeing what reached it. [OTLP/HTTP specification](https://opentelemetry.io/docs/specs/otlp/#otlphttp) · [Local Collector example](../examples/collector.yaml)

| Receiver outcome | OTel4D behavior |
| --- | --- |
| HTTP 200 with a valid empty export response | Confirms the entire batch. An empty Protobuf message can be zero bytes. |
| HTTP 200, partial success | Counts the receiver's `rejected_spans`. Retains a warning count when `error_message` is nonempty. A warning with zero rejected spans still confirms delivery. Completes the attempt without resending accepted spans. |
| HTTP 429, 502, 503 or 504 | Retries the same payload within the batch budget. Uses exponential backoff and jitter, starting at 200 ms, and honors a longer valid `Retry-After` in seconds or HTTP-date format. |
| Connection failure | Retries transient network exceptions within the same budget. A response lost after acceptance can cause a duplicate on retry. |
| Untrusted TLS certificate | Ends the batch as unconfirmed. Configure trust in the application's Windows environment. |
| Other HTTP status, including 3xx and 400 | Ends the batch as unconfirmed. The transport does not follow redirects with application credentials. |
| Invalid acknowledgement | Malformed Protobuf, a rejection count outside the batch, a response larger than 4 MiB or an incompatible media type leaves the batch unconfirmed. A nonempty body requires the Protobuf media type. |

The worker has a shared budget for a batch's attempts and waits. Individual connection and response timeout settings use up to 3,000 ms each or the remaining budget, whichever is smaller. Platform DNS, TLS and in-progress I/O can affect elapsed wall time. The response parser counts warnings without publishing arbitrary receiver text. [Transport implementation](../source/controller/OTel.Transport.Http.pas)

## Limits and counters

| Limit per enabled client or span | Behavior at the limit |
| --- | --- |
| 2,048 spans waiting in memory plus up to 128 in flight per client | Finishing a new span while the queue is full drops that span. A batch is eligible when full, after about 1,000 ms from the first queued span, or when a flush or shutdown wakes the worker. Time in a busy queue can exceed 1,000 ms. |
| 32 distinct attributes per span | Existing keys can still be updated. A new key beyond the limit, an empty key or a key over 256 UTF-16 units increments the span's OTLP dropped-attribute count. String values are truncated at 1,024 units. |
| 32 events per span | Extra events increment the span's OTLP dropped-event count. Exception events share this allowance. |
| Names and descriptions | Scope name, span name, event name and exception type use up to 256 UTF-16 units. Scope version uses 128, error descriptions and opt-in exception messages use 1,024. Empty span names become `unnamed`. |
| W3C state | The implementation accepts up to 512 characters and 32 unique state entries. An invalid state is omitted. |

Three cumulative client counters are accessible through `OTel.Api`. Read them before freeing the client.

| Counter | Interpretation |
| --- | --- |
| `DroppedSpans` | Finished recording spans that could not enter the queue, including spans finished after intake closed. Unsampled and disabled operations produce no recording and do not increment this counter. |
| `RejectedSpans` | Spans the receiver explicitly rejected **plus** spans for which delivery could not be confirmed. A terminal error for a batch of ten adds ten even if the receiver's final state is unknown. |
| `DeliveryWarnings` | Increments once for each response carrying a nonempty OTLP partial-success message, regardless of the batch size. |

## Flush and shutdown

1. Finish spans on producer threads. An open span has no queued representation.
2. Use `ForceFlush(TimeoutMs)` when a caller needs to wait for the spans already accepted at call time. Producers can continue submitting. Prefer this at diagnostic or lifecycle boundaries because the caller waits.
3. At process shutdown, stop new work, join producer threads, finish their spans and call `Shutdown(TimeoutMs)`. It closes intake, wakes the worker, and waits for pending batches. A tracer retained afterward yields nonrecording spans.
4. If shutdown times out, the worker can continue while the client is alive. A later call can wait again. Free the client once its lifetime is over. Destruction requests cancellation and joins the worker, so an active OS network call can extend the time spent in `Free`. Freeing after a timeout can abandon pending delivery.

Both calls return `False` on a wait timeout or when any drop or rejection has occurred during that client's lifetime. A later successful drain can resolve a timeout. Loss counters persist for the life of the client, so a later drain cannot turn a previous loss into a clean result. A warning alone keeps the Boolean result successful. Zero is a nonblocking check for these wait methods. It has different meaning from a zero exporter timeout in configuration. Crashes or forced termination lose any remaining in-memory spans.

## Troubleshooting

| Symptom | What to inspect |
| --- | --- |
| `TOTel.Open` raises `EOTelConfiguration` | Check code overrides, then the trace-specific and generic environment variables. Check URL syntax, protocol and encoded header names/values. An explicit configuration preview still validates the destination. |
| No spans and all counters are zero | Verify `OTEL_SDK_DISABLED`, the incoming sampled flag, `IsRecording` and whether the code finishes its spans. Check the actual service name, backend time range and Collector pipeline. |
| Rejections with HTTP 404 or 415 in receiver diagnostics | Compare the resolved destination against the receiver route and confirm it accepts binary OTLP/HTTP. A common mistake is setting a trace-specific URL to the base path. Port 4318 is the conventional HTTP listener. |
| Unconfirmed batches on HTTPS | Check the receiver certificate chain, hostname, proxy and credentials from the same Windows identity running the host. A Windows service can have different trust or proxy settings from an interactive user. |
| Drops with a slow receiver | Check queue pressure and receiver latency. Reduce high-frequency instrumentation or increase receiver throughput. A longer shutdown wait cannot recover spans already dropped at capture. |
| Child appears as a separate trace | Check incoming headers, activate the parent around the child, and pass a copy of the context across thread or task boundaries. |
| Duplicate spans at the destination | Compare span IDs. A lost acknowledgement can cause a retry with the same bytes. Design downstream processing to tolerate repeated delivery. |
| Collector shows spans but the backend does not | Inspect the Collector's traces pipeline, processors, exporter status and backend indexing. The local debug example writes to the terminal only. |

Use operation names with bounded cardinality. Review attribute values and status descriptions before capture. Keep request bodies, tokens, raw SQL parameters and personal information out of telemetry. Exception messages can contain all of these. Restrict access to detailed Collector output when using real application data.

## Verification

Run from the repository root. Repository checks require Python. The compiler and runtime checks require a RAD Studio 10.2 Command Prompt with Win32. The wire test also requires the official Python Protobuf bindings. They are a test dependency only.

```bat
python tools\check_project.py
python -m unittest discover -s tests -p "test_*.py"
tests\run-configuration.cmd
python -m pip install opentelemetry-proto==1.45.2
tests\run-traces.cmd
msbuild source\OTel4D.dproj /t:Build /p:Config=Release /p:Platform=Win32
```

Install the Python package in the development environment or virtual environment used for testing. If the desired interpreter is outside PATH, set `OTEL4D_TEST_PYTHON` to its executable path before running the trace script.

| Check | Evidence it provides |
| --- | --- |
| Repository checks | Layout and coding guardrails, local Markdown file references and policy regression tests. |
| Configuration consumer | Builds the Debug BPL and exercises the public configuration API, precedence, snapshot ownership, URL handling and invalid inputs. [Consumer](../tests/ConfigurationSmoke.dpr) |
| Trace consumer and independent decoder | A Win32 application emits spans to loopback. Official bindings decode service, scope, IDs, flags, times, scalar types, events and status. The receiver tests exact endpoints, retry requests, partial success, warning-only success, redirects, permanent errors and malformed acknowledgements. A delayed response exercises zero-timeout flush and shutdown. A 3,000-span run checks that unique deliveries plus local drops equal the number submitted. [Delphi consumer](../tests/TraceSmoke.dpr) · [Python verifier](../tests/verify_traces.py) |
| Official Collector | Follow the first-trace walkthrough and inspect the two decoded spans and their relationship. This exercises the actual receiver separately from the programmable test server. [Walkthrough](integration.md#run-the-local-example) |

**Additional verification during implementation.** On Tokyo Win32, an independent run exercised a source-linked application and a runtime-package consumer against the official Collector 0.165.0. In a separate slow-receiver run with eight producing threads and 4,096 finished spans, 2,176 unique spans reached the receiver and 1,920 were reported dropped. The sum accounted for all submissions. The split depends on receiver throughput and scheduling. Tests also exercised shutdown deadlines, thread-local parent restoration, a retained tracer after client destruction and untrusted TLS. These observations concern Win32 and local receivers. Production latency, backend retention and other targets require validation in the deployment environment.
