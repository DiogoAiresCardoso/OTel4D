# Translate OpenTelemetry examples to Delphi

This guide maps common OpenTelemetry patterns to the OTel4D API. The same concept can have a different lifetime or context model in another language. The official examples are references for the operation and its semantics. Delphi applications build against the OTel4D units or runtime package. [Official language documentation](https://opentelemetry.io/docs/languages/) · [Delphi integration](integration.md)

## Trace and context mapping

| Source language | Create and activate | Finish | Official example |
| --- | --- | --- | --- |
| C++ | `tracer->StartSpan(...)` creates the span. A `Scope` activates it. | `span->End()` ends the span. The scope object restores context. | [C++ instrumentation](https://opentelemetry.io/docs/languages/cpp/instrumentation/) |
| C#/.NET | `ActivitySource.StartActivity(...)` creates an activity that becomes current when it is started. Check for a null activity if no listener records it. | `using` disposes the activity. | [.NET tracing](https://opentelemetry.io/docs/languages/dotnet/traces/best-practices/) |
| Erlang/Elixir | Use Erlang's `?with_span` macro or Elixir's `Tracer.with_span` block. | The wrapper scopes and ends the span. | [Erlang and Elixir instrumentation](https://opentelemetry.io/docs/languages/erlang/instrumentation/) |
| Go | `ctx, span := tracer.Start(ctx, name)` returns the span and the context to pass to child calls. | `defer span.End()` schedules its end. | [Go instrumentation](https://opentelemetry.io/docs/languages/go/instrumentation/) |
| Java | `tracer.spanBuilder(name).startSpan()` creates it. `span.makeCurrent()` activates it inside a try-with-resources scope. | Close the scope and call `span.end()` in `finally`. | [Java API](https://opentelemetry.io/docs/languages/java/api/) |
| JavaScript/TypeScript | `tracer.startActiveSpan(name, callback)` creates it and activates context for the callback. `startSpan` just creates it. | Call `span.end()` in the callback, typically in `finally`. | [JavaScript instrumentation](https://opentelemetry.io/docs/languages/js/instrumentation/) |
| Kotlin | `tracer.startSpan(name)` creates a span. The Kotlin API provides its own mechanisms for scoping and coroutine context. | End an explicitly created span with `end()`. | [Kotlin instrumentation](https://opentelemetry.io/docs/languages/kotlin/instrumentation/) |
| PHP | `$tracer->spanBuilder($name)->startSpan()` creates it. `$span->activate()` returns a scope. | Detach the scope and end the span. | [PHP instrumentation](https://opentelemetry.io/docs/languages/php/instrumentation/) |
| Python | `with tracer.start_as_current_span(name) as span` starts and activates it. `start_span` just creates it. | The `with` block for `start_as_current_span` ends the span on exit. | [Python instrumentation](https://opentelemetry.io/docs/languages/python/instrumentation/) |
| Ruby | `tracer.in_span(name) do \|span\|` opens a scoped span. | The block ends the span. | [Ruby instrumentation](https://opentelemetry.io/docs/languages/ruby/instrumentation/) |
| Rust | The OpenTelemetry example starts a span with a builder and can attach a context for descendants. | End or release the span according to the Rust handle's ownership. | [Rust getting started](https://opentelemetry.io/docs/languages/rust/getting-started/) |
| Swift | `tracer.spanBuilder(spanName: name).startSpan()` creates it. An explicit parent or the active context supplies parentage. | Call `span.end()` at the chosen completion boundary. | [Swift instrumentation](https://opentelemetry.io/docs/languages/swift/instrumentation/) |
| Delphi | `Tracer.StartSpan(Name)` creates the span. `Span.WithContext(Action)` activates it on that thread and restores the previous context when the action exits. | Use `Span.Free` in `finally`. Call `Finish` first when recording must end earlier. | [Delphi API and ownership](integration.md#public-api-and-ownership) |

## Translate the operation

| In an upstream example | Use in Delphi | Delphi behavior |
| --- | --- | --- |
| Build or register SDK providers and an exporter | `Client := TOTel.Open(Options)` | An application-owned client snapshots the settings and owns delivery. Pass the client or an appropriate handle to instrumented modules. |
| Configure a resource and acquire a named tracer | `Options.ServiceName` and `Client.GetTracer('billing.workflow', '1.0')` | The service identifies the application. The tracer name and version identify the instrumentation module. Logs and metrics have their own scope names. |
| Activate a span and run child operations | `Span.WithContext(procedure begin ... end)` | Use the explicit scope before creating children or emitting correlated logs. Capture `TraceParent` and `TraceState` as strings and activate them in a new Delphi worker. |
| Set attributes, events, and errors | `Span.SetAttribute`, `AddEvent`, `RecordException`, and `SetStatus(ssError)` | Use scalar attributes and separate exception recording from status. Capture an exception message only when approved for telemetry. |
| Call a propagator on an HTTP carrier | Read inbound `traceparent` and `tracestate`, pass them to `StartSpan`, then write the outgoing child span's headers | The host supplies its HTTP carrier. Keep the business request's credentials together with the rest of that request. |
| Record through a logging API or appender | `Client.GetLogger(...)`, `Logger.Emit(...)`, and optional `TOTelAttributes` | Use an application-owned bridge for Delphi loggers. The capture uses the active context on the emitting thread. |
| Create a counter, up-down counter, or histogram | `Client.GetMeter(...)`, `Meter.CreateCounter`, `CreateUpDownCounter`, or `CreateHistogram` | Record with `Add(Int64)` or `RecordValue(Double)`. Use typed attributes for dimensions. Histograms and sums export cumulatively. |
| Install framework or database instrumentation | Instrument a Delphi boundary explicitly or migrate selected components to `TFDOtelQuery` and `TFDOtelStoredProc` | The host binds the FireDAC adapter at startup. Background task context, general framework interception, and zero-code injection require separate integration. |
| Force an export or stop a provider | `Client.ForceFlush(TimeoutMs)`, `Client.Shutdown(TimeoutMs)`, then `Client.Free` | Delivery waits are bounded and use the same deadline across active signals. Reuse one client across operations. |

For the three non-trace API surfaces in the upstream examples, see the [Java providers and APIs](https://opentelemetry.io/docs/languages/java/api/), [.NET metric instruments](https://opentelemetry.io/docs/languages/dotnet/metrics/instruments/), [.NET log correlation](https://opentelemetry.io/docs/languages/dotnet/logs/correlation/), [Go instrumentation](https://opentelemetry.io/docs/languages/go/instrumentation/), and the [Python instrumentation guide](https://opentelemetry.io/docs/languages/python/instrumentation/).

## Worked example

This Delphi method corresponds to a scoped span with structured logging and a duration metric. The caller supplies reused tracer, logger, and histogram handles from the same client. Define `Duration` with unit `s` when creating the histogram. The elapsed time uses a monotonic clock and includes failures.

```pascal
uses
  System.Diagnostics, System.SysUtils, OTel.Api;

procedure ProcessInvoice(const Tracer: TOTelTracer; const Logger: TOTelLogger;
  const Duration: TOTelHistogram; const Process: TProc);
var
  Span: TOTelSpan;
  Clock: TStopwatch;
begin
  Clock := TStopwatch.StartNew;
  Span := Tracer.StartSpan('invoice.process');
  try
    Span.WithContext(
      procedure
      begin
        try
          Process();
          Logger.Emit(llInfo, 'Invoice processed');
        except
          on E: Exception do
          begin
            Span.RecordException(E);
            Span.SetStatus(ssError);
            Logger.Emit(llError, 'Invoice processing failed');
            raise;
          end;
        end;
      end);
  finally
    Span.Free;
    Clock.Stop;
    Duration.RecordValue(Clock.ElapsedTicks / TStopwatch.Frequency);
  end;
end;
```

For example, if a Java or .NET service passes W3C headers to a Delphi HTTP API, create the Delphi server span with the explicit-parent overload and activate it around the handler. For an outgoing call, send the Delphi client span's trace headers. Each service exports its own signals to the Collector. Verify the shared trace ID and the parent span ID at each boundary. [Delphi carrier and worker examples](integration.md#distributed-requests-and-threads) · [W3C Trace Context](https://www.w3.org/TR/trace-context/)

For full examples and limits, see [logs, metrics, and FireDAC](telemetry.md), [source and verification map](source-map.md), and [official specifications and compatibility](opentelemetry-reference.md).
