---
name: review-engineering-change
description: Perform an independent review or implementation handoff for an OTel4D change using the engineering gates.
---

Establish the exact diff and intended behavior. Inspect production callers, claimed tests and the relevant engineering policies. Check ownership of managed values across threads, API and wire compatibility, sensitive data flow, idempotent shutdown and whether verification exercises real code. Use [the numbered rules](../../../docs/engineering/AI_GUARDRAILS.md) for actionable findings.

Give findings in priority order with file, behavior, impact and how to verify. Identify tests actually run, skipped targets and any remaining uncertainty. Preserve the patch during independent review. For a handoff, use the [definition of done](../../../docs/engineering/DEFINITION_OF_DONE.md) and identify who performed the independent review.
