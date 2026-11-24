# Delphi telemetry demo

Telemetry Demo is a VCL application for the local OpenTelemetry lab. Each click runs a synthetic order calculation. OTel4D sends its traces, logs and metrics as OTLP/HTTP Protobuf to the Collector. The form shows the result of the export and the IDs to look up in Grafana Explore.

## Build and run

Start the [local Compose lab](../../infra/observability/README.md). In RAD Studio 10.2 Tokyo, open [TelemetryDemo.dproj](TelemetryDemo.dproj), select Win32 and run the project. The project links the OTel4D units directly into the executable.

From a RAD Studio Command Prompt at the repository root, run the same build with:

```bat
msbuild examples\TelemetryDemo\TelemetryDemo.dproj /t:Build /p:Config=Release /p:Platform=Win32
examples\TelemetryDemo\Win32\Release\TelemetryDemo.exe
```

Leave the port at `4318` for the default Compose configuration. If you changed `OTLP_HTTP_PORT` in the lab, enter that port in the form. The demo also accepts `OTLP_HTTP_PORT` from the process environment as the initial value. It sends to `127.0.0.1` using explicit local export settings and synthetic data. Choose **Send sample** and wait for the acknowledgement. Copy the Trace ID or Span ID from the result.

The form stays responsive while the worker waits for export. An unavailable endpoint reports unconfirmed items. A new click after a failure or a port change starts a fresh telemetry session. With a healthy Collector, repeated clicks reuse one session and increment the same counter. The trace ID is different on every click.

## Query what the demo sent

Open [Grafana Explore](http://127.0.0.1:3000/explore) and choose each data source. The demo uses `service.name=otel4d-delphi-demo`.

| Data source | Query or action | Expected data |
| --- | --- | --- |
| Tempo | Choose **Trace ID** and paste the ID from the form | `demo.order.preview` with a child span named `demo.order.calculate` |
| Loki | Run the LogQL query below with the same Trace ID | The INFO message `Demo order calculated`, with the root span ID |
| Prometheus | `otel4d_demo_operations_total{service_name="otel4d-delphi-demo"}` | Completed calculations since this telemetry session started |
| Prometheus | `otel4d_demo_operation_duration_seconds_count{service_name="otel4d-delphi-demo"}` | Number of duration observations in the histogram |

```logql
{service_name="otel4d-delphi-demo"} |= "Demo order calculated" | trace_id = "TRACE_ID"
```

Use a recent time range for the log and metric queries. For the histogram, the `_sum` series gives the total duration in seconds.

## Code path

The [form](TelemetryDemo.Main.pas) validates the port and shows completion from the [send thread](TelemetryDemo.SendThread.pas). The [session](TelemetryDemo.Session.pas) owns the client, tracer, logger and metrics. It creates the calculation span and emits the log while the root span is active. The histogram records the root span's elapsed time. The worker flushes all three signals before reporting the result to the form.
