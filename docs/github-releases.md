# GitHub Releases

The [release workflow](../.github/workflows/release.yml) runs when a maintainer pushes a new annotated version tag in the form `vMAJOR.MINOR.PATCH`. It validates that the tag points to a commit in `main` and runs the repository checks. A separate GitHub-hosted job creates the release and generates the notes. GitHub provides **Source code (zip)** and **Source code (tar.gz)** from the repository contents at the tag. [GitHub release archives](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

Use the [local bundle guide](demo-bundle.md) to compile the Win32 demo and runtime packages on a Windows machine with Delphi 10.2 Tokyo.

## Create a version from main

After the release PR is merged into `main`, follow the [Gitflow release procedure](../CONTRIBUTING.md#publish-a-release-or-hotfix). Update the changelog and push the annotated tag for the merged commit. For example:

```sh
git fetch origin main
git tag -a v0.1.0 origin/main -m "Release OTel4D 0.1.0"
git push origin refs/tags/v0.1.0
```

Substitute the intended version and use `origin/main` only when it points to the intended release commit. Follow **Actions → Release OTel4D**. The release page lists the generated notes and the two source downloads.

The workflow publishes tags for commits that include the project's [Apache License 2.0](../LICENSE). Tags for earlier commits whose `LICENSE` records `License decision pending` produce drafts. The source downloads reflect the license and notices at the tagged commit. [Project licensing](../GOVERNANCE.md#licensing)

## Recover a failed run

Fix the GitHub Actions error and re-run the failed jobs from the original run. An existing release or draft for the tag retains its current contents. For a change to the tagged code, prepare a new version through Gitflow.
