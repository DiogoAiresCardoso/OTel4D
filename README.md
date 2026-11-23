# OTel4D

OTel4D sends traces, logs and metrics directly from a Delphi application to an OpenTelemetry Collector or a compatible backend over HTTP. It propagates W3C trace context, correlates logs, aggregates metrics and exports each signal as binary Protobuf. Optional FireDAC components instrument blocking queries and stored procedure calls. The verified target is Delphi 10.2 Tokyo Win32.

## Start here

| Goal | Guide |
| --- | --- |
| See a real parent and child span in a local Collector | [Build and run the first trace](docs/integration.md#run-the-local-example) |
| Integrate a desktop or service application | [Installation, configuration, API and context propagation](docs/integration.md) |
| Understand the internal MVC design and wire mapping | [Implementation guide and supported features](docs/implementation.md) |
| Diagnose missing spans or verify a build | [Delivery, shutdown, troubleshooting and tests](docs/operations.md) |
| Add logs, metrics and automatic FireDAC capture | [Telemetry API, configuration and FireDAC migration](docs/telemetry.md) |
| Review the implementation milestones | [Telemetry roadmap](docs/telemetry-roadmap.md) |

## Configure a Delphi application

Open [OTel4D.dproj](source/OTel4D.dproj) to build the runtime package. To compile the library into an application from source, add `source/controller`, `source/model/dto`, `source/model/dao`, `source/model/service` and `source/view` to its Delphi unit search path. Application code uses a single unit.

```pascal
program ShowTraceDestination;

{$APPTYPE CONSOLE}

uses
  OTel.Api;

type
  TExampleApplication = class
  public
    class procedure Run; static;
  end;

class procedure TExampleApplication.Run;
var
  Options: TOTelOptions;
  Config: TOTelConfiguration;
begin
  Options := TOTelOptions.Create;
  try
    Options.ServiceName := 'billing';
    Options.Endpoint := 'https://collector.example/otel';
    Config := TOTelConfigurationController.LoadConfiguration(Options);
    try
      Writeln(Config.TracesEndpoint);
    finally
      Config.Free;
    end;
  finally
    Options.Free;
  end;
end;

begin
  TExampleApplication.Run;
end.
```

`TOTelConfigurationController.LoadConfiguration` without arguments reads the process environment. The controller borrows any supplied options for the duration of the call. Each call returns a new, caller-owned configuration that can outlive the options. The example prints `https://collector.example/otel/v1/traces` with no network I/O.

When migrating from the record API, assigning one options or configuration variable to another shares the same object. Give each instance one owner. Create another `TOTelOptions` instance when settings need to be edited independently.

| Setting | Resolution order, highest priority first |
| --- | --- |
| Service name | `Options.ServiceName`, `OTEL_SERVICE_NAME`, then `unknown_service:<executable name>`. If the name is unavailable, the default is `unknown_service`. |
| Trace destination | `Options.TracesEndpoint`, `Options.Endpoint`, `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, `OTEL_EXPORTER_OTLP_ENDPOINT`, then `http://localhost:4318` as the base URL. |

Empty settings fall through to the next candidate. A base URL gets the relative path `v1/traces` after any existing prefix. A trace-specific URL keeps its path and query, with `/` used for an empty path. Supply an absolute HTTP or HTTPS URL and use ASCII or Punycode for hostnames. Each percent escape requires two hexadecimal digits. Valid escapes keep their original spelling. Invalid destinations, URL credentials and fragments raise `EOTelConfiguration`. The error omits the supplied URL. [OTLP/HTTP endpoint rules](https://opentelemetry.io/docs/specs/otel/protocol/exporter/#endpoint-urls-for-otlphttp) · [URI percent encoding](https://www.rfc-editor.org/rfc/rfc3986.html#section-2.1)

## Project layout

| Directory beside the package | Responsibility |
| --- | --- |
| `source/controller` | Public API, configuration loading, span capture, batching and HTTP delivery. |
| `source/model/dto` | Input options, configuration snapshots, span data and events. |
| `source/model/dao` | Reads the supported process environment variables. |
| `source/model/service` | Configuration precedence, identifiers, timestamps and scoped trace context. |
| `source/view` | Renders OTLP/HTTP endpoints, encodes trace batches and decodes acknowledgements. |

From a RAD Studio 10.2 Command Prompt at the repository root, run `tests\run-configuration.cmd` to build the Debug package and run a console consumer against it. The package build writes the BPL and DCP under `source\Win32\Debug` or `source\Win32\Release`, according to the selected configuration.

## Contribute

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for Gitflow, skills, reviews and validation. [AGENTS.md](AGENTS.md) is the entry point for engineering instructions. See [governance](GOVERNANCE.md), the [code of conduct](CODE_OF_CONDUCT.md), [security reporting](SECURITY.md) and [license status](LICENSE) before sharing or redistributing project material.
