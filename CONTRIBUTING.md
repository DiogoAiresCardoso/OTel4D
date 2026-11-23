# Working on OTel4D

OTel4D uses Gitflow. Start everyday work from `develop`. The `main` branch holds release history, and annotated tags such as `v0.1.0` identify published versions.

| Branch | Start from | Merge into | Purpose |
| --- | --- | --- | --- |
| `feature/<name>` | `develop` | `develop` | Add a capability, improve documentation, or refactor code. |
| `bugfix/<name>` | `develop` | `develop` | Fix a problem during development. |
| `release/<version>` | `develop` | `main`, then bring `main` back into `develop` | Stabilize and ship a version. |
| `hotfix/<version>` | `main` | `main`, then bring the fix into `develop` and any active release | Patch a published version. |

## Start a change

In a fresh clone with git-flow AVH installed, initialize the local settings and start a feature branch. The example uses a short English name that describes the work.

```sh
git switch develop
git pull --ff-only
git flow init -d -t v
git flow feature start propagate-trace-context
```

With plain Git, the equivalent of the last command is `git switch -c feature/propagate-trace-context develop`. When the change is ready, push the branch with `git push -u origin HEAD` and open a pull request targeting `develop`.

## Publish a release or hotfix

1. Update the starting branch with `git pull --ff-only`. For a release, start from `develop` with a branch such as `release/0.1.0`. For an urgent fix to a published version, start from `main` with a branch such as `hotfix/0.1.1`.
2. Push the branch and open a pull request into `main`. Use a merge commit to preserve the release branch history.
3. Fetch the merged commit. Tag that exact commit with an annotated tag, for example `git tag -a v0.1.0 <merge-commit> -m "Release OTel4D 0.1.0"`, then push it with `git push origin v0.1.0`. Substitute the released version in both commands.
4. Open a pull request from `main` into `develop` and merge it with a merge commit. If a hotfix shipped while a release branch was open, merge `main` into that release branch as well.

## Write for the next contributor

Use English for code comments, documentation, branch names, commit messages, and pull requests. Write a commit subject the way you would explain the change to a teammate. Lead with a verb and describe the outcome. Add a short body when the reason or tradeoff would be hard to infer from the diff.

- `Keep the trace context when a request moves to a worker thread`
- `Send completed spans in batches over HTTP`
- `Give pending traces time to finish during shutdown`

## Project skills and agents

Open the OTel4D Git root as the workspace. In Codex, trust the project after reviewing its configuration. Invoke a skill by name, for example `$assess-reuse` before introducing a second trace context implementation. Contributors using other tools can follow the same instructions directly.

| Task | Skill |
| --- | --- |
| Find existing behavior and decide what to reuse | [assess-reuse](.agents/skills/assess-reuse/SKILL.md) |
| Check a payload or delivery change against the wire contract | [verify-otlp-http](.agents/skills/verify-otlp-http/SKILL.md) |
| Reproduce a Delphi build for a stated platform | [verify-delphi-build](.agents/skills/verify-delphi-build/SKILL.md) |
| Review a diff and record the evidence | [review-engineering-change](.agents/skills/review-engineering-change/SKILL.md) |

For delegated work, ask Codex to use the [reuse_explorer](.codex/agents/reuse-explorer.toml), [validation_engineer](.codex/agents/validation-engineer.toml) or [engineering_reviewer](.codex/agents/engineering-reviewer.toml) role. Give it the revision, intended outcome and scope. Roles inherit the session's permissions. A maintainer reviews the evidence and owns approval.

When editing a project skill, keep its name and description as single-line plain YAML text so contributors can run the metadata check with the standard library. Run the Codex skill author's validator for full front matter validation.

Run the [quality gates](docs/engineering/QUALITY_GATES.md) locally before review. They also run in [GitHub Actions](.github/workflows/quality.yml). The quality guide explains how the owner can activate the branch ruleset once the status check and an eligible reviewer are available.

The [Codex command rules](.codex/rules/git-safety.rules) prompt on selected elevated Git and GitHub CLI command prefixes. Preview a match without running the command:

```sh
codex execpolicy check --pretty --rules .codex/rules/git-safety.rules -- git reset --hard HEAD
```

Argument reordering, aliases, wrappers, commands run outside Codex and other clients require independent controls. GitHub branch protection governs operations accepted by the remote.
