# Delphi telemetry demo

Telemetry Demo is a VCL application for the local OpenTelemetry lab. Each scenario simulates an order workflow. OTel4D sends its traces, logs and metrics as OTLP/HTTP Protobuf to the Collector. The form shows the result of the export and the IDs to look up in Grafana.

## Build and run

Start the [local Compose lab](../../infra/observability/README.md). In RAD Studio 10.2 Tokyo, open [TelemetryDemo.dproj](TelemetryDemo.dproj), select Win32 and run the project. The project links the OTel4D units directly into the executable.

From a RAD Studio Command Prompt at the repository root, run the same build with:

```bat
msbuild examples\TelemetryDemo\TelemetryDemo.dproj /t:Build /p:Config=Release /p:Platform=Win32
examples\TelemetryDemo\Win32\Release\TelemetryDemo.exe
```

Leave the port at `4318` for the default Compose configuration. If you changed `OTLP_HTTP_PORT` in the lab, enter that port in the form. The demo also accepts `OTLP_HTTP_PORT` from the process environment as the initial value. It sends to `127.0.0.1` using explicit local export settings and synthetic data. Select a scenario, click **Run scenario** and wait for the Collector acknowledgement. Copy the Trace ID or Span ID from the result.

The form stays responsive while the worker waits for export. An unavailable endpoint reports unconfirmed items. A new click after a delivery failure or a port change starts a fresh telemetry session. With a healthy Collector, repeated runs reuse the same session and increment the counter for the selected scenario. Each run gets a fresh trace ID.

## Scenarios

Every run emits `TRACE` and `DEBUG` logs, a root `demo.order.preview` span and an internal `demo.order.calculate` child. The scenario determines the remaining spans, log levels and stock adjustment.

| Scenario | Additional log levels | Trace outcome | Stock change |
| --- | --- | --- | --- |
| Successful order | `INFO` | Successful root and `CLIENT` reservation span | −3 |
| Recovered retry | `WARN`, `INFO` | Successful root with a retry event, one failed restock attempt and one successful attempt | +3 |
| Rejected order | `ERROR` | Failed root and internal validation span with a rejection event | 0 |
| Dependency unavailable | `FATAL` | Failed root and failed `CLIENT` reservation span | 0 |

The dependency failure ends the simulated operation. The demo remains available to run another scenario. Logs capture the ID of the span active at emission, so the warning and error logs correlate with the relevant child span. The attributes include a string scenario name, an integer quantity, a Boolean simulation flag and a double unit price.

## Query what the demo sent

Open the [OTel4D Delphi Demo dashboard](http://127.0.0.1:3000/d/otel4d-delphi-demo/otel4d-delphi-demo). Keep **Last 15 minutes** selected, run the four scenarios and refresh if necessary. **Scenario runs** counts each run, including simulated failures. **Mean operation duration** uses the cumulative histogram. **Inventory adjustment** is the signed cumulative stock change. Each card groups the values by scenario. In **Recent traces**, open an ID printed by the demo. In **Recent logs**, expand a log entry to inspect `trace_id`, `span_id` and `demo_scenario`. If a panel is empty, confirm the Collector acknowledgement and refresh the selected time range.

For a manual check, open [Grafana Explore](http://127.0.0.1:3000/explore) and choose each data source. The demo uses `service.name=otel4d-delphi-demo`.

| Data source | Query or action | Expected data |
| --- | --- | --- |
| Tempo | Choose **Trace ID** and paste the ID from the form | Root `demo.order.preview`, calculation span and scenario-specific children |
| Loki | Run the LogQL query below with the same Trace ID | Logs at the levels listed for the selected scenario |
| Prometheus | `otel4d_demo_operations_total{service_name="otel4d-delphi-demo",demo_scenario!=""}` | Cumulative runs per scenario |
| Prometheus | `otel4d_demo_operation_duration_seconds_count{service_name="otel4d-delphi-demo",demo_scenario!=""}` | Duration observations per scenario |
| Prometheus | `otel4d_demo_inventory_adjustment{service_name="otel4d-delphi-demo"}` | Cumulative signed stock adjustment per scenario |

```logql
{service_name="otel4d-delphi-demo"} | trace_id = "TRACE_ID"
```

Use a recent time range for the log and metric queries. For the histogram, the `_sum` series gives the total duration in seconds.

## Verify all four scenarios

Run each scenario and copy its Trace ID. Within 15 minutes, run the verifier from `infra/observability`, using the IDs in the order shown:

```powershell
docker compose run --rm --entrypoint python smoke /tests/verify_delphi_demo.py SUCCESS_TRACE_ID RETRY_TRACE_ID REJECTED_TRACE_ID UNAVAILABLE_TRACE_ID
```

The verifier checks span hierarchy, status and events in Tempo, exact log severities and span IDs in Loki, and the cumulative run count, signed inventory change and histogram observations in Prometheus. For the loopback protocol tests and the Tokyo Win32 package checks, see the [library verification guide](../../docs/operations.md#verification).

## Code path

The [form](TelemetryDemo.Main.pas) validates the port and shows completion from the [send thread](TelemetryDemo.SendThread.pas). The [session](TelemetryDemo.Session.pas) owns the client, tracer, logger and instruments. The histogram records the root span's elapsed time. The worker flushes all three signals before reporting the result to the form.
