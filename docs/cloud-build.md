# Build from Windows using a macOS runner

The repository includes `.github/workflows/macos-build.yml` for GitHub Actions. It runs on `macos-15`, records the runner's selected Xcode/Swift versions, validates project metadata, executes the geometry/export package tests, and compiles both Simulator Debug and unsigned iPad Release targets. A committed shared scheme makes the app discoverable without opening Xcode first.

## First run

1. Choose a GitHub repository for this source (a private repository is suitable).
2. Push the project including the hidden `.github` directory. Ensure Actions is enabled and the account has sufficient macOS runner quota/budget.
3. Open **Actions → macOS compile and tests**. A push starts a run automatically; **Run workflow** is also available once the workflow is on the default branch.
4. Inspect failures and download the `build-logs-...` artifact. The logs are retained for 14 days, including when a build step fails. Fix failures and push again.
5. Treat the gate as passed only after unit tests and both app compilations succeed on the same commit.

This workflow requires no Apple signing secrets and uploads only diagnostics. It does not install an application on iPad, exercise LiDAR, produce a signed IPA, or upload to TestFlight. Simulator compilation checks source compatibility, not sensor behavior.

The runner label is fixed, but its default Xcode installation can change as GitHub updates the image. Check the recorded toolchain before comparing runs; pin a verified installed Xcode version after the first successful run if strict reproducibility is required.

## Next gate: TestFlight

After compile verification, configure the owner's Apple Developer Program membership, App Store Connect app record, confirmed bundle identifier, signing certificate/provisioning, unique build number and required app assets. Store credentials in the CI secret store, never in the repository or chat. Add a separate manually triggered distribution workflow after these settings are available. Compilation success alone does not establish TestFlight readiness or physical-device acceptance.

## Current evidence

Prepared locally on Windows on 2026-10-14. No Git remote was configured and no macOS runner was connected, so no workflow run or successful Xcode compile is claimed.

References: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data).
