# Coding and data standards

Define Delphi DTOs and domain entities as classes. Implement behavior as methods on the responsible class across controllers, views, DAOs, services, tests and examples. Use private methods for helpers. Standalone functions and procedures are prohibited. Avoid defining record types in project code. Keep RTL and platform value types at the boundaries that use them. Document object ownership at public entry points, including the lifetime of returned snapshots.

Use intention-revealing English names and project formatting. Prefer typed domain values, named constants, explicit ownership and short routines. Use guard clauses to simplify valid paths and keep error handling close to the operation that failed. Avoid dead code, hidden mutable globals and generic catch-all handlers that hide application exceptions. Record necessary debt with impact and a follow-up.

Use try/finally for owned Delphi resources and acquired contexts. A queued item must own its data independently of a form, query or exception object. Treat wire IDs as fixed-width values, preserve byte order and use integer UTC timestamps and a monotonic duration source. Keep financial or decimal values exact whenever the contract requires it.

When a change touches persistence, preserve transaction ownership, isolation, referential integrity and idempotency. Version schema changes, test forward migration and recovery on representative data, and account for retention and deletion. Inspect repeated queries and plans when relevant. A FireDAC observer must preserve the host's SQL, transaction and exception behavior. Apply database controls only where the change uses a database.

Bound queues, request bodies and retries. Use backoff, cancellation and deadlines around external I/O. Verify memory, latency and discard behavior on the target platform. Introduce caching, lazy loading, pagination or a circuit breaker when the workload justifies them and define invalidation or recovery. Use diagnostic counters for drops and correlate logs with the originating span without recursively instrumenting delivery.
