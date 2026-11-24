# OTel4D Win32 demo bundle

Use this bundle to test OTel4D locally. It contains the Win32 `TelemetryDemo.exe`, the `OTel4D.bpl` runtime package, its `OTel4D.dcp` compile-time package, and the Delphi 10.2 Tokyo RTL and VCL runtimes used by the demo. The `observability` directory contains the Dockerfile, Compose configuration, dashboard and integration checks. See the included `LICENSE` and `NOTICE` for the OTel4D project. The Delphi runtimes follow the Embarcadero redistribution terms.

## Run the lab and demo

Extract the complete archive. On Windows, start Docker Desktop in Linux container mode. The first build needs the Grafana base image, which Docker downloads if it is missing. From the extracted directory, run:

```powershell
Set-Location observability
docker compose up -d --build --wait --wait-timeout 180
..\win32\TelemetryDemo.exe
```

The Dockerfile builds a Grafana LGTM image with the demo dashboard. The VCL executable runs on Windows and loads the BPLs next to it. Leave the Collector port at `4318`, choose a scenario and click **Run scenario**. After the Collector acknowledges the delivery, open the [OTel4D Delphi Demo dashboard](http://127.0.0.1:3000/d/otel4d-delphi-demo/otel4d-delphi-demo).

Use **Last 15 minutes** to see scenario counts, mean duration and stock adjustments. In **Recent traces**, compare the Trace ID with the value shown by the demo. In **Recent logs**, expand an entry to see the Trace ID and Span ID. A simulated scenario error can still be delivered successfully.

If a host port is occupied, copy `.env.example` to `.env` in `observability` and adjust the conflicting port. Use the configured `OTLP_HTTP_PORT` in the demo or the configured `GRAFANA_PORT` in the dashboard URL.

## Verify and manage the lab

```powershell
docker compose ps
docker compose run --rm smoke
docker compose logs --tail=100 lgtm
docker compose down
```

To verify the data produced by the Windows demo, run each scenario and then supply its Trace ID to the verifier in this order:

```powershell
docker compose run --rm --entrypoint python smoke /tests/verify_delphi_demo.py SUCCESS_TRACE_ID RETRY_TRACE_ID REJECTED_TRACE_ID UNAVAILABLE_TRACE_ID
```

Compose keeps its telemetry volume when you stop the lab with `down`.

## Rebuild from source

From a RAD Studio 10.2 Tokyo Command Prompt at the repository root, run:

```bat
powershell -NoProfile -File tools\build-demo-bundle.ps1
```

The script builds the `OTel4D.groupproj` group and writes `dist\OTel4D-win32-Release.zip`. Use `-Configuration Debug` for a Debug archive. The RAD Studio installation supplies the two Win32 runtime packages from its redistributable directory.
