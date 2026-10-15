# 3117 LiDAR SCAN

## Browser edition

The new [browser workspace source](browser/README.md) opens imported scans without installing an app: OBJ, ASCII PLY, XYZ and 3117 mesh/project JSON; interactive 3D viewing, A/B measurements, IndexedDB project storage, JSON backup and CSV reports. Run `node serve.mjs` from `browser/` for local use. This is **not live LiDAR capture** and does not replace native ARKit acquisition. Safari/iPad WebXR depth support is absent in the [MDN compatibility data](https://github.com/mdn/browser-compat-data/blob/main/api/XRCPUDepthInformation.json). Scan data are processed locally, not uploaded by the application. Physical iPad/browser validation remains outstanding.

`browser/` is the open-source snapshot of the separately managed Sites checkout (`web/`, ignored by this repository). Keep source changes synchronized before publishing. The hosted Site starts owner-private; an open-source repository does not automatically make the deployed Site public.

Native iPadOS LiDAR capture and scan-to-BIM foundation for **3117 BIM Management Co., Ltd.**

## Open source

This project is released under the [MIT license](LICENSE). See the [contribution guide](CONTRIBUTING.md) to report issues or contribute improvements. The license permits commercial reuse and modification, with preservation of its copyright and permission notices. Company names and logos do not imply endorsement of forks.

Apple SDKs and any future third-party integrations retain their own terms; they are not relicensed by this project. Open-source availability does not remove Apple signing, hardware or App Store distribution requirements. This repository is an early development project, not a production-ready or survey-validated release. Read [security reporting guidance](SECURITY.md) before reporting sensitive issues.

## Long-term product objective

**Scan → Point Cloud → Measurement → Building-element detection → Revit BIM Model**

3117 LiDAR SCAN will help field engineers turn existing-building captures into measured, reviewed, editable BIM elements for renovation, as-built documentation, and construction verification. Users must be able to trace each generated element back to its source scan and measurements. Human review and correction are required between detection and BIM generation. See the staged deliverables and acceptance gates in [the roadmap](docs/development-roadmap.md).

This is the product direction, not a claim of implemented end-to-end functionality. Initial depth/RGB voxel accumulation is implemented in source; robust reconstruction, element detection, and Revit generation remain future work. Physical-device acceptance remains unverified. See [depth capture and its limitations](docs/depth-point-cloud.md).

## Verified build

On 2026-10-14, commit `549c1cb2b8cba8fd0aa2a36397182aee7c6951a3` passed five geometry/export/measurement tests and both Simulator Debug and unsigned iPad Release builds using Xcode 16.4. [Build evidence](https://github.com/wirarua-stack/3117-LiDAR-SCAN/actions/runs/38499242569). This does not establish successful app launch, signing, TestFlight distribution, or LiDAR capture on a physical device.

The source includes `ARMeshAnchor` capture, live mesh visualization, named local archives, saved-model viewing with orbit/zoom and surface measurement, and OBJ export through the iPad share sheet. Save/load failures are reported instead of silently dismissed. Deleted projects leave geometry files in Application Support for recovery.

## What is implemented

- SwiftUI iPad application shell and project library
- Runtime LiDAR / scene-reconstruction capability gate
- Camera permission handling and ARKit world-tracking session
- Live mesh-anchor ingestion (no simulated scan data)
- ARKit sceneDepth + camera RGB sampling, high-confidence depth filtering and bounded 2 cm voxel accumulation across frames
- Depth-derived colored point-cloud archives/recovery and saved RGB point rendering, with a separate mesh measurement layer
- Local JSON project metadata and raw mesh archive persistence
- Point-to-point measurement (metres and millimetres)
- Saved-model measurement mode with visible A/B markers, connecting line, named saved measurements and endpoint recall
- UTF-8 CSV measurement reports with local coordinates, metre distances and validation caveats
- Cancellable background geometry preparation and staged model-loading feedback
- OBJ export for captured triangles
- ASCII PLY export of depth-derived points with RGB; XYZ exports coordinates only. Legacy mesh-only scans still export mesh vertices without color. Coordinates are metres, local Y-up, not georeferenced.
- Export-format history, project rename/duplicate, and unsaved-scan discard confirmation
- Periodic atomic recovery drafts and recovery into saved models after relaunch (last completed checkpoint only; not live AR session continuation)

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
