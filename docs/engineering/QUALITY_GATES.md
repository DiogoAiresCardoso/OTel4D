# Quality gates

Run `python tools/check_project.py` and `python -m unittest discover -s tests -p "test_*.py"` from the repository root with Python 3.11 or newer. On Windows, `py -3.11` or the full path to a suitable interpreter also works. These commands use only the standard library. The GitHub Actions job **Repository checks** runs the same commands on PRs targeting develop and main, and on pushes to those branches.

The repository gate checks the required policy files, local Markdown file references, skill metadata, agent TOML, the 28 guardrail identifiers, selected tracked secret patterns, generated IDE artifacts, forbidden Delphi Model imports, inward domain and application dependencies, matching DPK and DPROJ unit lists, and the one-class-per-unit rule. It checks common source patterns conservatively. Review conditional compilation, the full dependency graph and wire compatibility separately.

| Criterion | Acceptance evidence |
| --- | --- |
| Build | A runtime change compiles for the supported affected targets with zero errors. Record compiler, configuration and platform. From a licensed RAD Studio environment use the build command under [testing instructions](../../tests/AGENTS.md). |
| Tests | All applicable tests pass. Supply commands and results for unit, integration and contract checks as appropriate. A missing tool or runner is a reported gap. |
| Quality | Zero new lint errors, dependency cycles and unauthorized contract breaks. Review complexity, semantic duplication and regression risk. |
| Security | Zero exposed secrets, untreated critical findings and new high-severity findings. Review dependencies and advisories when affected. The checked-in scanner covers a few high-confidence patterns only. |
| Independent review | Record the reviewer, scope, findings and disposition. A human owns approval and merge. |
| Initial measurement targets | Aim for at least 80% coverage of new code, at most 3% duplication in new code and cognitive complexity of at most 15 per method. Record tool, scope and exception rationale when measuring. |

Coverage, duplication and cognitive complexity are initial targets from the constitution. Add a Delphi-capable measuring tool and baseline before making them blocking CI thresholds. The hosted job has no licensed Delphi toolchain. Supply local build evidence for runtime changes until a trusted licensed runner is available.

## Activate repository protection

The proposed [GitHub ruleset](../../.github/rulesets/gitflow.json) targets main and develop. It requires a pull request with one independent approval, a successful **Repository checks** job, and blocks deletion and force pushes. It grants no bypass. Importing or enabling it changes remote policy and needs owner authorization.

Before activation, land the CI workflow through the normal review process, observe the named check on GitHub, confirm private-repository ruleset support for the account and arrange an eligible second reviewer. An author cannot approve their own PR. In GitHub Settings → Rules → Rulesets, import the JSON, inspect both branch targets and activate it. Verify the effective rules for each branch and use a disposable PR to confirm that an absent check or approval blocks merge. Review, runner setup and enforcement have separate evidence. [GitHub repository rules](https://docs.github.com/en/rest/repos/rules)
