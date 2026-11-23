# Test changes

Use the [testing standard](../docs/engineering/TESTING_STANDARDS.md). Isolate the clock, ID source and network endpoint when order or timing forms part of the assertion. Use synthetic data and loopback receivers. Verify the unchanged public call path and include a regression case for the reported defect. Keep production code independent of test doubles. Record the compiler, architecture and actual test command.

## Build the Win32 package

Use the RAD Studio 10.2 Tokyo Command Prompt on a licensed Windows machine with the Win32 platform installed. Equivalently, call the installation's `bin\rsvars.bat` in a Command Prompt. From the repository root, when the package project and its sources are present, run:

```bat
msbuild source\OTel4D.dproj /t:Build /p:Config=Debug /p:Platform=Win32
```

Use a disposable checkout and set package output paths to a local build directory when validating an untrusted or unreleased change. Record whether the build used committed or working-tree inputs. A package build and a consumer exercising a real trace provide different evidence.

Run `tests\run-configuration.cmd` from a Tokyo Command Prompt to build the Debug package and exercise the public configuration API from a package-linked Win32 consumer. The consumer controls its own process environment. It checks setting precedence, fallback defaults, snapshot isolation, URL rendering and invalid input.

Run `tests\run-traces.cmd` to exercise trace capture and delivery through the package and decode actual HTTP requests using the official Python Protobuf bindings. Use the [verification guide](../docs/operations.md#verification) for prerequisites and the [Collector walkthrough](../docs/integration.md#run-the-local-example) for the backend interoperability check.

Run `tests\run-telemetry.cmd` for log correlation, metric aggregation and delivery checks. Run `tests\run-firedac.cmd` for FireDAC BPLs, the migrated DFM fixture, SQL behavior and three-signal validation. The [verification guide](../docs/operations.md#verification) lists the Firebird and Collector paths used by optional checks.
