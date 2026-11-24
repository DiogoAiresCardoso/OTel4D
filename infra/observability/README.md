# Local OpenTelemetry test lab

This lab exercises OTLP for future MaxxRural VCL, DataSnap and Horse integrations. Run it on Docker Desktop in Linux container mode with WSL 2 on Windows. Compose runs the Collector, Grafana, Tempo, Prometheus, Loki and Pyroscope together in the official Grafana LGTM image. A separate one-shot container runs the synthetic test with Python's standard library. [Grafana LGTM source](https://github.com/grafana/docker-otel-lgtm) · [OTLP specification](https://opentelemetry.io/docs/specs/otlp/)

## Start and verify

From the repository root, enter the lab directory. The first pull downloads the images for both services.

```powershell
Set-Location infra/observability
docker version
docker compose version
docker compose config -q
docker compose --profile test pull
docker compose up -d --wait --wait-timeout 180
docker compose ps
docker compose run --rm smoke
docker compose logs --tail=100 lgtm
```

Compose waits for LGTM's built-in health check. The smoke container sends one span, one gauge data point and one correlated INFO log by OTLP/HTTP JSON. It accepts HTTP 200 with a valid JSON acknowledgement and zero rejected items. Transient failures get limited retries. The test then queries all three Grafana data sources for the exact run. It exits nonzero on delivery or query failure.

| Service | Windows host | Inside the Compose network |
| --- | --- | --- |
| Grafana | [http://localhost:3000](http://localhost:3000) | `http://lgtm:3000` |
| OTLP/gRPC | `localhost:4317` | `lgtm:4317` |
| OTLP/HTTP | `http://localhost:4318` | `http://lgtm:4318` |
| Traces | `http://localhost:4318/v1/traces` | `http://lgtm:4318/v1/traces` |
| Metrics | `http://localhost:4318/v1/metrics` | `http://lgtm:4318/v1/metrics` |
| Logs | `http://localhost:4318/v1/logs` | `http://lgtm:4318/v1/logs` |

The three published ports bind only to IPv4 loopback. Use `127.0.0.1` if your client resolves `localhost` to IPv6 first. Grafana's default laboratory credentials are `admin` / `admin` if prompted. Tempo, Prometheus and Loki are exposed through Grafana's provisioned data sources. Compose uses a dedicated bridge network and the bundled Collector exports to destinations inside the LGTM container. The lab disables OBI, Grafana's automatic update checks and plugin installation, and optional usage reporting in Grafana, Tempo, Loki and Pyroscope.

If another service uses a port, copy `.env.example` to `.env` and change the corresponding host port before running Compose. The internal endpoints stay the same. Keep `.env` local. To check that the default published gRPC port accepts a TCP connection from Windows, run `Test-NetConnection 127.0.0.1 -Port 4317`. This check covers connectivity. The smoke test exports using OTLP/HTTP.

## Find a run in Grafana Explore

Choose a recent time range, such as **Last 15 minutes**, then select the relevant data source. Replace `TRACE_ID` and `SPAN_ID` with the IDs printed by the smoke container.

| Data source | Query | Expected result |
| --- | --- | --- |
| Tempo | Select **Trace ID** and enter the trace ID | Span `smoke.test` for service `dac-otel-smoke` with the printed span ID |
| Prometheus | `dac_otel_smoke{smoke_run_id="TRACE_ID"}` | Gauge value `1`. Use a range query for an older sample. |
| Loki | Run the LogQL query below | INFO log with both IDs in structured metadata |

Use this LogQL query in the Loki editor:

```logql
{service_name="dac-otel-smoke"} |= "OpenTelemetry smoke test" | trace_id = "TRACE_ID" | span_id = "SPAN_ID" | severity_text = "INFO"
```

To query an existing fixture without submitting new data, run `docker compose run --rm smoke --verify-only TRACE_ID SPAN_ID`. Run this soon after initial ingestion because the verifier uses an instant Prometheus query and a recent Loki window. [Grafana data source API](https://grafana.com/docs/grafana/latest/developer-resources/api-reference/http-api/api-legacy/data_source/)

## Manage the lab

```powershell
docker compose ps
docker compose logs -f lgtm
docker compose down
```

`docker compose down` removes the containers and network and preserves the named telemetry volume. A complete reset uses `docker compose down -v` and deletes that volume. Run the reset only when you explicitly want to discard the laboratory data.

## Validation

Validated on November 23, 2026, with Docker Desktop 4.100.1, Docker Engine 29.9.3 (Linux amd64) and Docker Compose 5.7.1.

| Image or component | Version observed |
| --- | --- |
| `grafana/otel-lgtm:0.41.1` | Digest `sha256:1b852b77d7bcadb7699bfe7c78a51d059dff85168de674728cf7abf4474645e5` |
| `python:3.13-alpine` | Python 3.13.18, digest `sha256:9ef1a599f863231c3d91e941389bfdc4a2d6070557243d54df1a4e57015b960e` |
| Grafana | 13.3.1 |
| OpenTelemetry Collector | 0.165.0 |
| Tempo | 3.1.1 |
| Prometheus | 3.16.0 |
| Loki | 3.7.10 |
| Pyroscope | 2.4.3 |

Compose reported LGTM healthy using its image-provided health check. All three OTLP/HTTP JSON exports returned HTTP 200 with zero rejected items. The backend queries and Grafana Explore returned the same synthetic fixtures.

| Signal | Evidence |
| --- | --- |
| Traces | Tempo found span `smoke.test` for TraceID `897f6e9b696d4ecba069362f91bb5d56` and SpanID `51dacd5e11114f69`. |
| Metrics | Prometheus returned `dac_otel_smoke=1` with the same TraceID in `smoke_run_id`. |
| Logs | Loki returned `OpenTelemetry smoke test` at INFO level with both correlation IDs. |

After `docker compose restart -t 60 lgtm`, the same data was still queryable with `--verify-only` and the named volume `otel-local-test_telemetry-data`. A Windows client connected to the published gRPC port over TCP. Full OTLP/gRPC export is outside the verification scope.
