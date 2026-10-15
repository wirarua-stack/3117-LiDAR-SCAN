# Contributing to 3117 LiDAR SCAN

Contributions should advance Scan → Point Cloud → Measurement → Reviewed building elements → Revit BIM.

## Start here

- Read the [architecture](docs/architecture.md), [roadmap](docs/development-roadmap.md) and [implementation status](docs/implementation-status.md).
- Open an issue describing a bug or proposed feature before making a substantial change. Small fixes can go directly to a pull request.
- Fork the repository and create a descriptive branch. Keep each pull request focused and explain the behavior changed and evidence of validation.

## Build and test

Use macOS with Xcode; the verified baseline is Xcode 16.4. Run `swift test` at the repository root for geometry, export, measurement and persistence tests. Open `ios/3117LiDARScan.xcodeproj` and use the shared `LiDARScan` scheme for the app. The CI workflow also compiles Simulator Debug and unsigned device Release builds.

LiDAR capture requires a supported physical device. Report the device model, OS, capture conditions and reference measurements for hardware tests. If hardware testing was not performed, state that explicitly. Never present synthetic fixtures as real sensor capture. Follow [the test plan](docs/testing-plan.md).

## Contribution boundaries

- Submit only work you have the right to contribute under the project's MIT license. Identify third-party code and its license; do not copy proprietary scanner code or assets.
- Do not commit credentials, signing files, private site scans, camera frames, client names, or personal information. Use small, clearly labeled synthetic fixtures for automated tests.
- Preserve original capture provenance, units and coordinate transforms. Generated BIM elements must remain reviewable and traceable.
- Do not add signing secrets to pull-request workflows or use privileged workflows to execute untrusted contributions.
- Be constructive and respectful in issues and reviews. Focus feedback on the work.

Source contributions and review do not imply permission to publish an official App Store release or use company branding to imply endorsement.
