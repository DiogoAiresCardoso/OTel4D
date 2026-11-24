# GitHub Releases

The [release workflow](../.github/workflows/release.yml) runs when a maintainer pushes a new annotated version tag in the form `vMAJOR.MINOR.PATCH`. It checks that the tag identifies a commit in `main` and runs the repository checks before scheduling a Win32 build. The Windows job builds the same ZIP as the [local bundle](demo-bundle.md). A separate GitHub-hosted job attaches `OTel4D-vMAJOR.MINOR.PATCH-win32.zip` and its `.sha256` file to the release using the workflow's `GITHUB_TOKEN`.

## Connect the Windows build runner

1. Prepare a dedicated Windows runner with a licensed RAD Studio 10.2 Tokyo installation, Win32 VCL, MSBuild and the Win32 redistributables. Use a dedicated Windows account that can build from the RAD Studio Command Prompt. Verify it with `powershell -NoProfile -File tools\build-demo-bundle.ps1` from the repository root.
2. In the repository, open **Settings → Actions → Runners → New self-hosted runner**. Select Windows and the runner's architecture. Follow GitHub's setup commands in the dedicated environment. Add `delphi-tokyo` to the runner's default labels during configuration or through its label settings. Use an up-to-date runner so it can execute the pinned Node.js actions.
3. If RAD Studio uses a custom installation directory, add the `DELPHI_TOKYO_ROOT` repository variable under **Settings → Secrets and variables → Actions → Variables**. The default is `C:\Program Files (x86)\Embarcadero\Studio\19.0`. Wait for the runner to appear online before pushing a version tag.

Keep workflow edits and tag creation limited to trusted maintainers. Use the dedicated runner for this private repository and keep developer credentials out of its Windows account. [GitHub self-hosted runner setup](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)

## Create a version from main

After the release PR is merged into `main`, follow the [Gitflow release procedure](../CONTRIBUTING.md#publish-a-release-or-hotfix). Update the changelog and push the annotated tag for the merged commit. For example:

```sh
git fetch origin main
git tag -a v0.1.0 origin/main -m "Release OTel4D 0.1.0"
git push origin refs/tags/v0.1.0
```

Substitute the intended version and use `origin/main` only when it points to the intended release commit. Follow **Actions → Release OTel4D**. The build waits for an online runner with the `delphi-tokyo` label. The release job generates notes from GitHub and attaches the two files before publication.

While [LICENSE](../LICENSE) records `License decision pending`, the workflow stages the completed bundle in a draft. Before publishing, the maintainer records the license and dependency notice decision in [GOVERNANCE.md](../GOVERNANCE.md). Version tags for subsequent commits with the decision recorded publish automatically. For a built draft, use the GitHub Releases interface to review the notes and publish once the policy is satisfied.

## Recover a failed run

Fix the runner, toolchain or GitHub Actions error and re-run the failed jobs from the original Actions run. If the seven-day build artifact expired, re-run all jobs to rebuild it. The workflow resumes its own draft and replaces the two draft assets together from the same archive. A published version with the expected assets is already complete. For a change to the tagged code, prepare a new version through Gitflow.
