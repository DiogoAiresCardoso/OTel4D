# Project governance

The repository owner, [DiogoAiresCardoso](https://github.com/DiogoAiresCardoso), maintains the project. Contributors can propose a change through an issue or a pull request. The owner can delegate a module to an accepting maintainer by updating CODEOWNERS. Maintainers review compatibility, evidence and licensing, explain material decisions in the PR, and record significant architectural choices in an ADR.

Anyone may propose a guardrail change in a dedicated or clearly identified diff with its rationale and expected effect. Have a reviewer other than the author examine policy changes. An agent review can inform this decision. A human maintainer owns merge and release decisions. Contributors are responsible for AI-assisted work, its provenance and the accuracy of the evidence they submit.

Use semantic versioning for releases, document user-facing changes in the [changelog](CHANGELOG.md) and follow the [release procedure](CONTRIBUTING.md#publish-a-release-or-hotfix).

## Licensing

The owner selected [Apache License 2.0](LICENSE) (`Apache-2.0`) for the original OTel4D code, examples and documentation, starting with version 1.0.1. Preserve the [project notice](NOTICE) when redistributing the project.

GitHub releases contain source archives. The locally built demo bundle uses the RTL and VCL redistributables from a RAD Studio installation. Those files follow the [Embarcadero redistribution terms](https://docwiki.embarcadero.com/RADStudio/Athens/en/Software_License_Requirements). The Docker lab references external container images whose components follow their respective licenses.
