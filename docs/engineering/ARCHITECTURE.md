# Architecture standard

Use the domain vocabulary of the OpenTelemetry specification. An instrumentation scope identifies the code emitting telemetry. Its tracer creates spans. A trace relates spans, a resource describes the observed entity, and context carries the active span across calls. Design the public contract before introducing an integration. For each public change identify accepted inputs, ownership, concurrency, lifecycle, error behavior and compatibility with existing callers.

Keep MVC inside the library as described in [ADR 0001](../adr/0001-library-mvc-and-otlp-http.md). Domain units must stay independent of GUI, FireDAC, HTTP clients and codecs. Views read immutable domain data. Controllers coordinate capture and delivery and receive infrastructure dependencies at construction. Use narrow integration contracts where a real dependency must vary. Review both interface and implementation uses clauses for new cycles.

Evolve incrementally. Record important design changes with the context, alternatives, decision, consequences, compatibility impact and verification evidence. Keep older ADRs and link a superseding decision. A source-level or wire-level break needs explicit authorization and a migration path.
