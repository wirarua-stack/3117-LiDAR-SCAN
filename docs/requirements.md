# Requirements and feasibility

## Long-term workflow requirements

The product shall support **Scan → Point Cloud → Measurement → Building-element detection → Revit BIM Model** for existing-building documentation, renovation and construction verification.

- Preserve the original capture and record the origin, axes, units and transforms for every derived artifact.
- Generate an inspectable point cloud before downstream cloud measurements and element detection; identify any mesh-derived data explicitly.
- Store measurements with their source revision, calibration evidence and uncertainty. Define acceptable tolerance per job before acceptance testing.
- Present detected walls, floors, ceilings and openings as candidates with confidence and supporting geometry. Allow correction, acceptance and rejection.
- Generate editable Revit elements only from reviewed specifications, with explicit level/type/host mappings and a record of source evidence. Report unsupported cases for manual modeling.
- Preserve scan-to-element traceability so corrections and repeat imports can be reviewed without silently duplicating BIM elements.

These are future acceptance requirements. The current mesh-capture foundation does not yet satisfy the full workflow.

## Feasible MVP

ARKit's `ARWorldTrackingConfiguration` supports mesh reconstruction only on hardware that reports support for `sceneReconstruction`. The application checks this at runtime, starts a real world-tracking session, and obtains `ARMeshAnchor` geometry. Camera permission is mandatory. Apple documents that scene reconstruction produces a polygonal estimate of the physical environment and requires a support check before enabling it: [scene reconstruction](https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/scenereconstruction).

## Accuracy boundary

LiDAR scan results are spatial geometry, not survey-grade truth. Capture validation against known dimensions is required per job. ARKit's local coordinate frame is not a surveyed coordinate reference system.

## Privacy

Captures remain local in the MVP. Camera imagery and geometry must be treated as sensitive site data. Obtain site permission before scanning, protect exports, and define retention policy before enabling cloud processing.

## API and license compatibility

The MVP uses Apple frameworks included with iPadOS/Xcode: SwiftUI, ARKit, RealityKit, AVFoundation, and SIMD. Apple platform terms, signing requirements, and the supported-device list must be verified at release time. The code has no third-party runtime dependencies. Any later Open3D, E57, LAS/LAZ, IFC, or Autodesk Revit API dependency needs a version-specific legal/license and interoperability assessment before shipping.
