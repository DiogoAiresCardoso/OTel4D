# Changelog

## Unreleased

- Changed the Delphi configuration API to use classes. Migrate calls to `TOTelConfigurationController.LoadConfiguration`, construct overrides with `TOTelOptions.Create`, and free each options object and returned configuration when finished. Rebuild consumers of the previous package.

- Added the Delphi 10.2 Win32 runtime package and a configuration API for service identity and OTLP/HTTP trace destinations.

- Added contributor and agent guidance for the Delphi library, local guardrails and repeatable repository checks.
