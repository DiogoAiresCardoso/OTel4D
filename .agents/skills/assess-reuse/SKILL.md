---
name: assess-reuse
description: Trace an OTel4D feature to existing Delphi units, callers and contracts before adding a shared rule, adapter or dependency.
---

Start at the proposed public call and inspect the closest scoped AGENTS.md. Search source, package declarations, tests and existing adapters by intent and alternate names. Verify RTL member names in the installed target version. For a proposed external library, check existing dependencies, license and supported targets.

Return the strongest candidate with a file and symbol, ownership and concurrency implications, and what existing callers assume. If there is no match, give the searched scope and explain the smallest new responsibility. See [reuse policy](../../../docs/engineering/REUSABILITY.md).
