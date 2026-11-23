# Engineering principles

Define the caller's contract and the failure behavior before choosing an abstraction. Give each module one coherent responsibility (SRP). Extend stable behavior through composition when another implementation is actually needed (OCP). Preserve preconditions, results and effects across substitutions (LSP). Keep interfaces focused on the caller's needs (ISP). Let domain code depend on small contracts where infrastructure must vary (DIP).

Keep one owner for each business rule and configuration value (DRY, SSOT). Favor a straightforward implementation (KISS, YAGNI). Treat repeated knowledge as evidence for extraction; the rule of three is a prompt to investigate, not a numerical gate. Keep responsibilities separate, hide mutable state and avoid traversing another object's internals. Use names and defaults that make behavior unsurprising. Prefer high cohesion, low coupling and explicit side effects.

Fail early on invalid configuration. Isolate operational telemetry failures so the host can continue business work. Improve touched code incrementally and record deliberate tradeoffs. Measure before optimizing. The [reuse procedure](REUSABILITY.md) and [architecture standard](ARCHITECTURE.md) turn these principles into review questions.
