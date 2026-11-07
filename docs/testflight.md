# TestFlight from iPad / cloud — 3117 LiDAR SCAN

## Status and boundaries

The repository now has a **manual-only** distribution workflow. This is implementation, not evidence of a signed build, TestFlight availability or physical LiDAR success. The historical [run 38682410041](https://github.com/wirarua-stack/3117-LiDAR-SCAN/actions/runs/38682410041) passed unsigned compilation and core tests on 2026-10-15. Do not reuse that result as validation of these changes.

The GitHub connector used for implementation cannot inspect/manage Apple accounts, GitHub environment protection or secret inventory. Their status is **unknown**, not asserted absent. Do not send certificates, passwords, P8 keys, Apple passwords or recovery codes in chat/issues/PRs.

## Account-owner setup (browser on iPad is sufficient for these portals)

1. Confirm active Apple Developer Program membership and acceptance of current agreements. Record the 10-character Team ID.
2. Register an explicit App ID in Certificates, Identifiers & Profiles. The repository's default is `com.3117bim.lidarscan`; confirm ownership or choose your own identifier. It must match the profile and App Store Connect app record exactly. Create that iOS app record in App Store Connect.
3. Supply an **Apple Distribution certificate WITH its private key**, exported as password-protected P12, and an **App Store Connect distribution provisioning profile** for that certificate/App ID. A `.cer` alone cannot sign. Development, Ad Hoc and enterprise profiles are rejected.
4. For upload, create an App Store Connect **team API key** with Developer role or the minimum role that permits uploads to this app. Supply its Key ID, Issuer ID and downloaded `.p8`. An individual key is not supported by this workflow. Owner/Admin access may be required to enable API access/create the team key.
5. Create GitHub environment **`ios-distribution`**. Configure required reviewer(s), selected deployment branch **main only**, and disable administrator bypass before entering any secrets. Enable prevent-self-review when another authorized reviewer is available; a sole owner must be able to approve their own run or appoint a reviewer. Protect main and require review of workflow/signing-script changes. A YAML environment declaration alone does NOT configure these protections.
6. Add the variables/secrets below to that environment (not repository-wide secrets). Do not run distribution until protection rules are checked. If the repository becomes private, confirm the GitHub plan still supports these rules.

| Kind | Exact name | Value |
|---|---|---|
| Variable | `APPLE_TEAM_ID` | Apple Developer Team ID |
| Variable | `APP_BUNDLE_ID` | Confirmed registered Bundle Identifier |
| Secret | `IOS_DISTRIBUTION_P12_BASE64` | Base64 of the password-protected P12 including private key |
| Secret | `IOS_DISTRIBUTION_P12_PASSWORD` | Nonempty P12 password |
| Secret | `IOS_APP_STORE_PROFILE_BASE64` | Base64 of App Store Connect `.mobileprovision` |
| Secret, upload only | `ASC_KEY_ID` | Team API Key ID |
| Secret, upload only | `ASC_ISSUER_ID` | Team API Issuer ID |
| Secret, upload only | `ASC_PRIVATE_KEY` | Full original P8 PEM text, including header/footer |

Signing-only mode does not require App Store Connect API secrets. The approval authorizes the selected mode for the exact commit; no push, PR, tag or successful CI automatically signs/uploads. Administrators and anyone able to change protected workflows remain trusted principals.

### If no P12 exists and there is no personal Mac

A Mac is not needed to generate a signing key/CSR. The owner or trusted administrator can use OpenSSL on Windows/Linux or a **trusted private cloud terminal** accessed from the iPad. Protect that terminal and its storage. Do not put a private key in GitHub artifacts, commits or public cloud terminals.

```sh
# Run in your own private credential workspace, not the repository.
# OpenSSL prompts for encryption passwords; never add passwords to command history.
openssl genrsa -aes256 -out distribution.key 2048
openssl req -new -key distribution.key -out distribution.csr
# Upload only distribution.csr in Apple Developer > Certificates > Apple Distribution.
# Download the resulting distribution.cer, then:
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey distribution.key -in distribution.pem -out distribution.p12
openssl base64 -A -in distribution.p12 -out distribution.p12.base64
openssl base64 -A -in AppStore.mobileprovision -out profile.base64
```

Select that certificate when creating the App Store Connect provisioning profile in Apple's portal. Enter the resulting base64 values directly in GitHub Environment Secrets and retain encrypted backups under the owner's control. This bootstrap is an owner credential operation and is not performed by CI. If the owner has only an iPad and no private terminal, an authorized administrator must supply the P12/profile or a private cloud workspace must first be arranged; this repository does not magically create an Apple identity.

## Release procedure on iPad Safari

1. Merge the reviewed PR after the unsigned macOS CI passes. Open **Actions → Signed iPad build and TestFlight → Run workflow**, select `main`.
2. Copy the full 40-character main commit SHA into `expected_sha`. Select `build-only` for the first signed trial, check `authorize_signing`, specify version (default `0.2.0`) and an unused build number (for example `3`). Version/build are validated and verified inside the exported IPA. Use an increasing build number for each upload, including reruns after an uncertain upload result. Do not rerun an already uploaded number.
3. CI first tests and compiles that exact dispatch commit without credentials. Then the `ios-distribution` environment waits for its configured reviewer. Inspect commit, inputs and CI before approval.
4. Signing validates profile expiry, team, explicit bundle ID and App Store distribution type; imports P12 into an ephemeral keychain; archives; exports a manual-signing IPA; verifies its signature and packaged version/identifier/iPad target. It does not automatically create or repair Apple certificates/profiles.
5. A signed IPA and `evidence.json` are retained for **one day**. No signing keychain, P12, P8, provisioning file or raw signing logs are uploaded. An App Store IPA is **not directly installable by tapping it on an iPad**. Downloading the artifact is not installation evidence. Treat artifacts as accessible to users with repository Actions read access.
6. When ready to upload, start a new run with `mode=testflight`, authorize signing and type exactly **`UPLOAD_TO_TESTFLIGHT`**. Select a fresh build number and approve the environment job. The workflow validates the IPA with Apple and uploads it. Cancellation/failure does not trigger automatic retry; check App Store Connect before retrying if upload status is uncertain.
7. Wait for Apple processing in App Store Connect. Resolve processing errors, export-compliance questions and any required beta metadata. The workflow does not answer legal/compliance questions on the owner's behalf or automatically invite testers. Add the processed build to an internal testing group with an eligible App Store Connect user, or configure external testing/Beta App Review as required.
8. Install Apple's TestFlight app on the iPad Pro, accept the owner's testing invitation, then install **3117 LiDAR SCAN**. No personal Mac is needed for build, upload or installation through this route.

## Toolchain and assets

Both unsigned CI and distribution pin `DEVELOPER_DIR` to Xcode **26.2** on GitHub `macos-15`. Apple requires Xcode 26+ / iOS 26+ SDK for uploads from April 28, 2026. Deployment minimum remains iPadOS 17; verify the actual device meets it and has LiDAR. If GitHub removes this Xcode image, update both workflows together and rerun CI before signing. Do not silently fall back to Xcode 16.4.

An original geometric development App Icon is included at all required iPad sizes plus opaque 1024px marketing size. It can be replaced with the approved brand icon before release. Version fields now use build settings rather than hardcoded Info.plist values. No encryption-compliance declaration was guessed. Apple-side metadata/compliance and upload validation remain account-owner gates.

## Record evidence separately for each gate

| Gate | Required evidence |
|---|---|
| Unsigned CI | Run URL + commit SHA + tests/Simulator/device compilation success |
| Signed IPA | Distribution run + version/build + IPA hash + signature verification |
| Upload | Successful upload step; does not prove processing success |
| TestFlight availability | Processed build visible/assigned in App Store Connect |
| iPad installation | TestFlight version/build on the named iPad model/iPadOS version |
| Physical LiDAR acceptance | Recorded scan/measurement/export tests below |

Device acceptance: camera permission allow/deny; LiDAR capability gate; scan a small measured area; pause/resume; save/reopen; inspect RGB point cloud and mesh; measure a reference distance and record error; export PLY/XYZ/OBJ and measurement CSV, reopen independently; background/interruption/recovery and thermal/memory observations. Record expected/actual results, version/build, device/iPadOS, sample files and screenshots without private site information. Never mark this gate passed from synthetic tests or simulator compilation.

## Failure handling / credential rotation

Missing values report **names only**. Wrong/expired profile or identity stops before upload. Archive/export failures deliberately suppress raw logs because these can expose signing metadata; first reproduce compile failures in unsigned CI, then inspect the owner's profile/certificate pairing. Cleanup runs with `always()`; GitHub-hosted runners are ephemeral, including hard cancellation. Never switch this workflow to a persistent self-hosted runner without redesigning cleanup/isolation. Revoke and replace compromised/expired credentials in Apple's portal and the environment; do not paste them into a troubleshooting message.

Official references: [SDK requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a), [upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [GitHub signing guidance](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [environment protection](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments), [runner toolchain inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md).
