# Security and privacy

Identify the trust boundary, protected data, expected caller and possible failure before changing an integration. Validate external endpoints, incoming trace headers and size limits. Encode output for its destination. Authenticate peers with TLS validation; authorize privileged operations separately at the service that owns them. Use parameterized queries when executing SQL.

Minimize permissions and retained data. Never commit credentials or put authorization headers, raw SQL parameters, personal identifiers or sensitive baggage into default diagnostics. Use synthetic fixtures and redact before placing data in a queue. Fail closed for authorization and validation. A telemetry transport failure must preserve the application's original result or exception.

For new dependencies and build inputs, verify provenance, version, license, maintenance and relevant advisories. Pin CI actions to reviewed revisions. Keep workflows read-only unless a particular job requires additional rights. Report exposures privately through [the disclosure policy](../../SECURITY.md). For a critical change, document the threat, mitigating control and residual risk. Relevant references include OWASP ASVS, NIST SSDF and the OpenSSF OSPS Baseline.
