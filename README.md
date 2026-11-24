# OTel4D

OTel4D is an independent Delphi library that sends traces, logs, and metrics from a Windows application to an OpenTelemetry Collector or compatible receiver. It uses binary Protobuf over OTLP/HTTP and interoperates with applications in other languages through W3C Trace Context. Optional FireDAC components capture blocking database operations. The verified target is Delphi 10.2 Tokyo Win32.

## Get started

1. Add `OTel.Api` to your application. [Build the runtime package or link the sources](docs/integration.md#link-an-existing-application).
2. Start a Collector or obtain the base HTTPS URL and ingestion credentials for your receiver. [Run the local example](docs/integration.md#run-the-local-example) or [configure the client in Delphi](docs/integration.md#configure-bearer-authentication-in-delphi).
3. Open a client at startup, then use its tracer, logger, or meter. Finish spans with `Free` in a `finally` block and call `Shutdown` when the application stops. [Instrument your application](docs/integration.md#public-api-and-ownership) · [Add logs, metrics, and FireDAC](docs/telemetry.md).

For a linked application that opens its client with `TOTel.Open`, set the process environment before startup. This PowerShell example assumes the host already provided the ingestion token in `OTEL_INGEST_TOKEN`.

```powershell
$env:OTEL_SERVICE_NAME = 'billing'
$env:OTEL_EXPORTER_OTLP_ENDPOINT = 'https://collector.example/otel'
$env:OTEL_EXPORTER_OTLP_PROTOCOL = 'http/protobuf'
$env:OTEL_EXPORTER_OTLP_HEADERS = "Authorization=Bearer%20$env:OTEL_INGEST_TOKEN"
```

The base URL gets the signal suffix, for example `/otel/v1/traces`. For a receiver with custom routes or credentials, set the exact endpoint and headers for each signal. [Configuration rules](docs/integration.md#configuration-reference) · [Logs and metrics configuration](docs/telemetry.md#configure-the-signals)

## Documentation

Browse the guides in the [OTel4D project wiki](https://github.com/DiogoAiresCardoso/OTel4D/wiki).

| Task | Guide |
| --- | --- |
| Learn the design and why each subsystem works this way | [Implementation and decisions](docs/implementation.md) |
| Find the units responsible for a behavior | [Source and verification map](docs/source-map.md) |
| Translate an OpenTelemetry example from another language | [Language-to-Delphi guide](docs/delphi-crosswalk.md) |
| Read the official specifications and see where OTel4D implements a subset | [OpenTelemetry references and compatibility](docs/opentelemetry-reference.md) |
| Set up an application or propagate a trace between services | [Delphi integration](docs/integration.md) |
| Instrument logs, metrics, or FireDAC | [Signals and database instrumentation](docs/telemetry.md) |
| Understand acknowledgement, retries, counters, and shutdown | [Operations and verification](docs/operations.md) |
| Run the demo and inspect all three signals in Grafana | [Win32 demo and lab](docs/demo-bundle.md) · [Local Compose lab](infra/observability/README.md) |

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for the review and verification workflow, [AGENTS.md](AGENTS.md) for engineering instructions, and [security reporting](SECURITY.md) to report a vulnerability. OTel4D is distributed under the Apache License 2.0. [License](LICENSE) · [Notices](NOTICE) · [Governance](GOVERNANCE.md)
