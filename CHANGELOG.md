# Changelog

## Unreleased

- Send manually instrumented Delphi traces over OTLP/HTTP with binary Protobuf, W3C parent propagation, background batching and bounded retries. Added a runnable Collector example and guides for application integration, internals and operations.

- Reject incomplete or nonhexadecimal percent escapes in trace destinations. The DAO, service and view now raise `EArgumentNilException` for missing required options. The public configuration loader still accepts omitted overrides.

- Changed the Delphi configuration API to use classes. Migrate calls to `TOTelConfigurationController.LoadConfiguration`, construct overrides with `TOTelOptions.Create`, and free each options object and returned configuration when finished. Rebuild consumers of the previous package.

- Added the Delphi 10.2 Win32 runtime package and a configuration API for service identity and OTLP/HTTP trace destinations.

- Added contributor and agent guidance for the Delphi library, local guardrails and repeatable repository checks.
