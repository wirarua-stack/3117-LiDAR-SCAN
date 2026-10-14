# 3117 LiDAR SCAN

Native iPadOS LiDAR capture and scan-to-BIM foundation for **3117 BIM Management Co., Ltd.**

## Long-term product objective

**Scan → Point Cloud → Measurement → Building-element detection → Revit BIM Model**

3117 LiDAR SCAN will help field engineers turn existing-building captures into measured, reviewed, editable BIM elements for renovation, as-built documentation, and construction verification. Users must be able to trace each generated element back to its source scan and measurements. Human review and correction are required between detection and BIM generation. See the staged deliverables and acceptance gates in [the roadmap](docs/development-roadmap.md).

This is the product direction, not a claim of implemented end-to-end functionality. Point-cloud fusion, element detection, and Revit generation remain to be built. Xcode compilation passed on GitHub Actions; physical-device acceptance remains unverified.

## Verified build

On 2026-10-14, commit `549c1cb2b8cba8fd0aa2a36397182aee7c6951a3` passed five geometry/export/measurement tests and both Simulator Debug and unsigned iPad Release builds using Xcode 16.4. [Build evidence](https://github.com/wirarua-stack/3117-LiDAR-SCAN/actions/runs/38499242569). This does not establish successful app launch, signing, TestFlight distribution, or LiDAR capture on a physical device.

The source includes `ARMeshAnchor` capture, live mesh visualization, named local archives, saved-model viewing with orbit/zoom and surface measurement, and OBJ export through the iPad share sheet. Save/load failures are reported instead of silently dismissed. Deleted projects leave geometry files in Application Support for recovery.

## What is implemented

- SwiftUI iPad application shell and project library
- Runtime LiDAR / scene-reconstruction capability gate
- Camera permission handling and ARKit world-tracking session
- Live mesh-anchor ingestion (no simulated scan data)
- Local JSON project metadata and raw mesh archive persistence
- Point-to-point measurement (metres and millimetres)
- OBJ export for captured triangles

## Build on macOS

Without a local Mac, follow [the cloud build guide](docs/cloud-build.md). The GitHub Actions workflow checks tests and unsigned compilation before any TestFlight setup.

1. Open `ios/3117LiDARScan.xcodeproj` in Xcode 15.4+ on a Mac.
2. Set the run destination to a LiDAR-capable iPad Pro (or other supported iPad with LiDAR).
3. In Signing & Capabilities, select a development team; add the camera privacy text from `ios/App/Info.plist` to the app target if Xcode does not import it automatically.
4. Build and run. Choose **New Scan**, grant camera access, move slowly around the subject, then finish and export.

The repository also includes `Package.swift` for the portable unit-test target. `ios/App/Info.plist` is wired into the Xcode target; select a development team before installing on hardware.

## Constraints

ARKit mesh reconstruction requires a physical supported device. Simulator, Windows, and non-LiDAR iPads cannot validate capture. OBJ export is implemented; texture mapping, E57/LAS/IFC, automatic BIM classification, and Revit integration are planned work rather than represented as complete.

See [documentation](docs/architecture.md) and [testing procedure](docs/testing-plan.md).
