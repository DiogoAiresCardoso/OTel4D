# Integrate OTel4D into a Delphi application

## Configure the client in Delphi

Add `OTel.Api` to the host unit. Run this fragment in your application's startup code, where `FClient` is a `TOTelTraceClient` field and `Options` is a local `TOTelOptions` variable. The application owns the returned client. The options can be freed immediately after `Open`.

```pascal
Options := TOTelOptions.Create;
try
  Options.ServiceName := 'billing';
  Options.Endpoint := 'https://collector.example/otel';
  Options.SdkDisabled := False;
  Options.TraceProtocol := 'http/protobuf';
  Options.LogsProtocol := 'http/protobuf';
  Options.MetricsProtocol := 'http/protobuf';
  Options.TraceTimeoutMs := 5000;
  Options.LogsTimeoutMs := 5000;
  Options.MetricsTimeoutMs := 5000;
  Options.MetricsIntervalMs := 60000;
  FClient := TOTel.Open(Options);
finally
  Options.Free;
end;
```

In a VCL app, hold the client on the application or a long-lived data module and create it before starting producers. In a service, create it during startup and reuse it across requests. Obtain a tracer, logger, or meter through that client. On shutdown, stop and join producers, release instrumentation handles, call `FClient.Shutdown(10000)`, and free the client. [Complete startup, capture, and shutdown example](../examples/ConfiguredTelemetry.dpr) · [Delivery lifecycle](operations.md#flush-and-shutdown)

### Configure Bearer authentication in Delphi

With an HTTPS receiver, read the raw ingestion token from the host's secret configuration. Assign the complete export headers before calling `TOTel.Open(Options)`. The header parser decodes `%20` into the space after `Bearer`.

```pascal
Authorization := 'Authorization=Bearer%20' + IngestionToken;
Options.TraceHeaders := Authorization;
Options.LogsHeaders := Authorization;
Options.MetricsHeaders := Authorization;
```

Provide the full list of headers for each signal when routing or credentials differ. Change credentials by draining the old client and opening a new client with the updated settings. [OTLP exporter configuration](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)

### Use an exact endpoint for a signal

Keep `Endpoint` as the common base and assign the exact URLs only where the receiver needs custom routes.

```pascal
Options.Endpoint := 'https://collector.example/otel';
Options.TracesEndpoint := 'https://traces.example/custom/ingest';
Options.LogsEndpoint := 'https://logs.example/ingest';
```

The trace and log URLs are used as supplied. Metrics go to `https://collector.example/otel/v1/metrics`. The VCL demo targets the loopback lab and configures the port in `TDemoTelemetrySession.OpenClient`. [Demo client construction](../examples/TelemetryDemo/TelemetryDemo.Session.pas)

## Run the local example

Use Windows, Delphi 10.2 Tokyo Win32, and an OpenTelemetry Collector distribution with the OTLP receiver and debug exporter. The example configures the service and receiver in Delphi and sends synthetic traces, logs, and metrics. [Collector installation](https://opentelemetry.io/docs/collector/installation/) · [Collector configuration file](../examples/collector.yaml)

1. From the repository root, start the Collector in one Command Prompt.

   ```bat
   otelcol.exe --config=examples\collector.yaml
   ```

2. In a separate RAD Studio 10.2 Command Prompt, build the runtime package and the console example.

   ```bat
   msbuild source\OTel4D.dproj /t:Build /p:Config=Debug /p:Platform=Win32
   pushd source\Win32\Debug
   dcc32 -B -Q -LUrtl;OTel4D -U. -N0. -E. ..\..\..\examples\ConfiguredTelemetry.dpr
   ConfiguredTelemetry.exe
   popd
   ```

3. Find service `billing-code-demo` and scope `example.billing` in the Collector output. The four `invoice.issue_batch` spans have matching INFO log records. The `example.invoices.issued` counter exports cumulative values of **3**, **6**, and **8** for the three flushes. [Complete Delphi source](../examples/ConfiguredTelemetry.dpr) · [Cumulative counter chart](telemetry.md#record-metrics)

The console example uses `http://127.0.0.1:4318` by default. An optional first argument replaces that base URL for a local receiver using another port. The program contains the export settings. Any environment-driven exporter or header fallback still applies when its corresponding option is unset. Run the example in a prompt with clean telemetry settings when reproducing the output above.

For a smaller trace-only example, compile `FirstTrace.dpr` with the same command and use `FirstTrace.exe`. The parent `invoice.issue` and its child `invoice.calculate_total` share a trace ID. [Trace-only source](../examples/FirstTrace.dpr)

## Link an existing application

**Compile the sources into the executable.** Add `source/domain`, `source/application`, `source/bootstrap`, `source/adapters/api`, `source/adapters/configuration`, `source/adapters/database`, `source/adapters/otlp`, `source/adapters/runtime`, and `source/adapters/windows` to the application's Delphi unit search path. Add `OTel.Api` to the instrumented unit's `uses` clause. This mode compiles the library alongside the host and works without the OTel4D BPL at deployment.

**Use runtime packages.** Build the DPROJ with the same Delphi version, platform and configuration as your host. Enable runtime packages in the application, include `OTel4D`, and add the package output directory to the compiler's search path for the DCP. Deploy the matching `OTel4D.bpl` and required Embarcadero runtime BPLs where Windows can load them. The project writes the BPL and DCP to `source\Win32\Debug` or `source\Win32\Release`. Rebuild consumers when changing the package's public classes. [Package project](../source/OTel4D.dproj)

Open one client during application or service startup. Reuse a tracer for a module, controller or subsystem. Stop accepting work on shutdown, let producers finish their spans, call `Shutdown` with the host's budget and then release the client. In VCL or FMX, run startup and teardown from application lifecycle code. A form paint handler or a per-request flush would put avoidable work on the UI or request thread.

**Existing executables and zero-code instrumentation.** The current integration requires rebuilding the host with OTel4D and adding instrumentation at the operations you want to observe. Environment variables configure a linked client. They do not attach OTel4D to an existing executable or start collecting FireDAC, VCL or HTTP operations. The `debug` exporter in the walkthrough belongs to the local Collector and only prints what it receives.

## Configuration reference

Options passed to `TOTel.Open(Options)` override the process environment read at open time. Each client retains its own resolved settings. To inspect the service name, endpoint and timeout before starting delivery, call `TOTelConfigurationController.LoadConfiguration(Options)` and free the returned snapshot. The snapshot can contain raw authentication headers, so print only the fields appropriate for your diagnostics.

| Option | Environment precedence | Default and behavior |
| --- | --- | --- |
| `ServiceName` | `OTEL_SERVICE_NAME` | `unknown_service:<executable name>`, or `unknown_service` if unavailable. Set a stable value across instances of one service. |
| `TracesEndpoint`, `Endpoint` | `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, then `OTEL_EXPORTER_OTLP_ENDPOINT` | Base URL `http://localhost:4318`. An explicit endpoint in code takes priority over both environment variables. Within either source the trace-specific setting wins. |
| `TraceProtocol` | `OTEL_EXPORTER_OTLP_TRACES_PROTOCOL`, then `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf`. Opening an enabled client with an unsupported protocol raises `EOTelConfiguration`. |
| `TraceHeaders` | `OTEL_EXPORTER_OTLP_TRACES_HEADERS`, then `OTEL_EXPORTER_OTLP_HEADERS` | Empty. The most specific nonempty setting supplies the entire list. |
| `TraceTimeoutMs` | `OTEL_EXPORTER_OTLP_TRACES_TIMEOUT`, then `OTEL_EXPORTER_OTLP_TIMEOUT` | 10,000 ms per batch including retry waits. A missing or invalid environment value falls through. An explicit negative value raises `EOTelConfiguration`. Zero selects the implementation's largest budget, 2,147,483,647 ms. |
| `SdkDisabled` | `OTEL_SDK_DISABLED` | False. Case-insensitive `true` disables recording and bypasses exporter setup at open time. Assigning `False` in code explicitly overrides a disabled environment. |

**Endpoint examples.** A base URL of `https://collector.example/tenant/a` yields `https://collector.example/tenant/a/v1/traces`. A trace-specific URL of `https://collector.example/custom?region=west` is used as supplied. A trace-specific URL consisting only of scheme and authority uses the path `/`. Destinations must be absolute HTTP(S) URLs with valid percent escapes. URL credentials and fragments raise a configuration exception. Use ASCII or Punycode for hostnames. [OTLP endpoint rules](https://opentelemetry.io/docs/specs/otel/protocol/exporter/#endpoint-urls-for-otlphttp)

**Authentication.** Use HTTPS with a trusted certificate for remote receivers. Supply authentication through the host's secret configuration, for example a trace-headers value shaped like `Authorization=Bearer%20TOKEN,X-Tenant=example`. Replace the placeholder at runtime. A comma separates assignments. Encode a comma inside a value as `%2C`. A literal plus stays a plus. OTel4D rejects duplicate header names, malformed escapes, control characters, reserved transport headers and header settings longer than 16,384 Delphi string units. Keep credentials and raw receiver messages out of application diagnostics.

**Configuration precedence.** Explicit values in code take priority for supported options. Empty string settings fall through to environment values. Set `Options.Logs.Exporter` or `Options.Metrics.Exporter` to `'none'` to turn a signal off in Delphi. `'otlp'` explicitly enables it. A signal's `BaseEndpoint` overrides the common base URL, while its explicit `Endpoint` wins over either base. Enabled exporters are validated during `TOTel.Open`. Array, sampler, batch processor, resource-attribute and other generic SDK settings outside the table have no configuration binding in this version.

## Public API and ownership

Application code imports `OTel.Api`. The application owns each returned client, tracer, span and configuration snapshot. Local object assignment aliases an instance. Free each object once and use `try/finally` at its ownership boundary. [Public facade](../source/adapters/api/OTel.Api.pas) · [Runnable ownership example](../examples/FirstTrace.dpr)

| Call | Contract |
| --- | --- |
| `TOTel.Open([Options])` | Returns a client. An enabled client validates export settings and starts a worker. Opening does not probe the destination. |
| `Client.GetTracer(ScopeName [, ScopeVersion])` | Returns a tracer identifying the code emitting spans. Use a stable module name. An empty name becomes `OTel4D`. |
| `Tracer.StartSpan(Name [, Kind])` | Returns a caller-owned span. Uses the current thread's active parent, otherwise creates a sampled root. Default kind is `skInternal`. |
| `Tracer.StartSpan(Name, Kind, TraceParent [, TraceState])` | Accepts incoming W3C headers. A valid explicit parent takes priority. An invalid one falls back to the active context or a new root. |
| `Span.SetAttribute(Key, Value)` | Supports `string`, `Int64`, `Boolean` and `Double`. Use an explicit cast for numeric literals when the chosen overload matters. |
| `Span.AddEvent(Name)` | Adds a named timestamped event. |
| `Span.RecordException(E [, IncludeMessage])` | Adds an exception event with the Delphi exception class. Message capture is opt-in. Set error status separately. |
| `Span.SetStatus(Value [, Description])` | Status starts at `ssUnset`. Use `ssError` with a sanitized description for failure. `ssOk` takes precedence over error and cannot subsequently be downgraded. |
| `Span.WithContext(Action)` | Runs an anonymous procedure with the span active on the current thread and restores the previous context even if the action raises. |
| `Span.IsRecording`, `TraceParent`, `TraceState` | Inspect recording before computing expensive attributes. The header properties can also carry an unsampled context downstream. |
| `Span.Finish`, `Span.Free` | `Finish` detaches and submits data once. `Free` finishes automatically and destroys the span. Explicitly finishing early still requires freeing the object. |
| `Client.ForceFlush([TimeoutMs])`, `Client.Shutdown([TimeoutMs])` | Both return a Boolean. Shutdown closes intake. The default wait is 10,000 ms. See the precise semantics of timeouts, warnings and cumulative loss. [Delivery lifecycle](operations.md#flush-and-shutdown) |

## Distributed requests and threads

For an incoming HTTP request, read `traceparent` and optional `tracestate` case-insensitively from your framework. Start the server span with the explicit parent overload. Run the handler inside `ServerSpan.WithContext`. For an outgoing HTTP call, create a `skClient` child and put **that child's** `TraceParent` and optional `TraceState` in the outgoing request. Replace existing propagation headers and omit an empty value. This connects the server, outbound call and downstream handler in the same trace. Export authentication headers belong only on the export request. [W3C Trace Context](https://www.w3.org/TR/trace-context/)

For example, a host method can wrap a request handler using the following body. Here `Tracer` is an existing tracer, `ParentHeader` and `StateHeader` are strings obtained from the inbound request and `HandleRequest` is the host's synchronous method.

```pascal
var
  ServerSpan: TOTelSpan;
begin
  ServerSpan := Tracer.StartSpan('orders.receive', skServer, ParentHeader, StateHeader);
  try
    try
      ServerSpan.WithContext(procedure begin HandleRequest; end);
    except
      on E: Exception do
      begin
        ServerSpan.RecordException(E);
        ServerSpan.SetStatus(ssError, 'Request processing failed');
        raise;
      end;
    end;
  finally
    ServerSpan.Free;
  end;
end;
```

For a fresh outbound request using Delphi's HTTP client, build the propagation headers from the active client span. In this method fragment, `Headers` is a local `TNetHeaders`, `Http` is a host-owned `THTTPClient` and `Url` is the business destination. The host imports `System.Net.URLClient` and `System.Net.HttpClient` for these types. Keep business request credentials separate from the headers configured on `TOTelOptions`.

```pascal
ClientSpan := Tracer.StartSpan('inventory.lookup', skClient);
try
  SetLength(Headers, 0);
  if ClientSpan.TraceParent <> '' then
  begin
    SetLength(Headers, 1);
    Headers[0] := TNetHeader.Create('traceparent', ClientSpan.TraceParent);
    if ClientSpan.TraceState <> '' then
    begin
      SetLength(Headers, 2);
      Headers[1] := TNetHeader.Create('tracestate', ClientSpan.TraceState);
    end;
  end;
  Response := Http.Get(Url, nil, Headers);
finally
  ClientSpan.Free;
end;
```

The host owns the business response and decides how its HTTP status affects the operation. If a request already has other headers, replace only the propagation entries and preserve the host's authorization and content negotiation settings.

`TOTelTraceContext.CurrentParent` and `CurrentState` read the active header strings. A newly started span becomes active only inside `WithContext`. When scheduling work on another thread, copy the current header strings before dispatch. On that thread call `TOTelTraceContext.WithContext(Parent, State, Action)` and create the child inside the action using the ordinary `StartSpan` overload. Keep the tracer alive until the worker finishes. Capturing the span object in an asynchronous closure also requires controlling its lifetime. A Delphi anonymous method captures variables by reference, so give each work item its own header values.

A valid unsampled parent produces a propagating child with the sampled bit cleared and no queued span. A disabled client forwards an existing valid context and produces an empty context for a root. Invalid `tracestate` is discarded independently from a valid `traceparent`. Treat incoming propagation values as untrusted routing metadata. Only forward them across boundaries where the host intends to continue a trace.
