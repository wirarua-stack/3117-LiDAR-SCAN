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

The private repository is now connected at `https://github.com/wirarua-stack/3117-LiDAR-SCAN`. On 2026-10-14, [run 38499242569](https://github.com/wirarua-stack/3117-LiDAR-SCAN/actions/runs/38499242569) succeeded for commit `549c1cb2b8cba8fd0aa2a36397182aee7c6951a3`, using Xcode 16.4 and the iOS 18.5 SDK. All five package tests passed, as did Simulator Debug and unsigned iPad Release compilation. Diagnostic artifact: `build-logs-38499242569-1` (14-day retention). No signing or physical-device test was performed.

References: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data).
