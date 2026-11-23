# OTel4D engineering instructions

OTel4D is a Delphi library for direct OTLP/HTTP delivery. Start at the Git root. These instructions apply to contributors and coding agents throughout the repository. Read the nearest scoped instructions before editing source or tests.

1. Read [the contribution guide](CONTRIBUTING.md) and [the guardrails](docs/engineering/AI_GUARDRAILS.md). Inspect branch, working tree, callers, public contracts and existing tests. Preserve other contributors' edits.
2. Search for an existing implementation by behavior and follow [the reuse decision](docs/engineering/REUSABILITY.md). Define the observable acceptance criteria and the smallest change that meets them.
3. Resolve tradeoffs in this order: security, privacy and data integrity; functional correctness; contracts and compatibility; architecture; maintainability and testability; simplicity and reuse; measured performance. Surface conflicts that need a maintainer's decision.
4. Apply [the engineering principles](docs/engineering/PRINCIPLES.md) and the relevant [architecture](docs/engineering/ARCHITECTURE.md), [coding](docs/engineering/CODING_STANDARDS.md), [security](docs/engineering/SECURITY_STANDARDS.md) and [testing](docs/engineering/TESTING_STANDARDS.md) policies.
5. Run the applicable [quality gates](docs/engineering/QUALITY_GATES.md). Self-review the diff and deliver the evidence in the [definition of done](docs/engineering/DEFINITION_OF_DONE.md). Attribute independent review to the person or agent that actually performed it.

Use English for repository content and natural English commit subjects. Follow Gitflow in CONTRIBUTING.md. Keep repository guidance separate from machine-specific configuration, credentials and private user data.

## Project tools

The reusable skills and optional Codex roles are listed in the [contributor setup](CONTRIBUTING.md#project-skills-and-agents). Humans and other agents can run the same checks directly. Apply [UI guidance](docs/engineering/UI_UX_STANDARDS.md) to changes that introduce a user interface.
