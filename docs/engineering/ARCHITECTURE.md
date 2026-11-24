# Architecture standard

Use the domain vocabulary of the OpenTelemetry specification. An instrumentation scope identifies the code emitting telemetry. Its tracer creates spans. A trace relates spans, a resource describes the observed entity, and context carries the active span across calls. Design the public contract before introducing an integration. For each public change identify accepted inputs, ownership, concurrency, lifecycle, error behavior and compatibility with existing callers.

Follow [ADR 0003](../adr/0003-hexagonal-telemetry.md). Domain units depend on domain and the RTL. Application units depend on domain, application ports and the RTL. Platform services, driver hooks and wire codecs live in adapters. Bootstrap selects concrete implementations and injects them by interface through constructors. Review both interface and implementation uses clauses for new cycles.

Evolve incrementally. Record important design changes with the context, alternatives, decision, consequences, compatibility impact and verification evidence. Keep older ADRs and link a superseding decision. A source-level or wire-level break needs explicit authorization and a migration path.
