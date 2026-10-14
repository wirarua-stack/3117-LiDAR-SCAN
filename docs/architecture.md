# Architecture

```text
iPad LiDAR + RGB + motion
          ↓ ARKit world tracking / scene reconstruction
ARMeshAnchor updates → mesh archive → OBJ export
          ↓
 local project metadata (Application Support)
          ↓
 future: cleanup → plane candidates → human review → BIM/Revit
```

The app is offline-first. `ScanCoordinator` owns the AR session and only serializes `ARMeshAnchor` data delivered by the hardware session. `ProjectLibrary` owns JSON metadata. Geometry is deliberately separate from the project index so later processing can add derived artifacts without overwriting capture evidence. The live view enables RealityKit's scene-understanding wireframe overlay, which Apple describes as a depth-colored scene mesh: [showSceneUnderstanding](https://developer.apple.com/documentation/realitykit/arview/debugoptions-swift.struct/showsceneunderstanding).

## BIM boundary

A triangle mesh is not a parametric BIM model. A later candidate-detection service may identify planar walls, floors, ceilings, and openings; a reviewer must confirm dimensions, types, levels, and relationships before IFC or Revit elements are generated.

## Target architecture

The long-term primary workflow is **Scan → Point Cloud → Measurement → Building-element detection → Revit BIM Model**. The diagram above describes only the current capture foundation.

Capture will retain synchronized depth, camera intrinsics, poses, confidence where available, and RGB references. Point-cloud processing will validate and register observations into a documented project coordinate frame, with provenance linking derived points to capture sessions. Sampling an existing mesh must be labeled as mesh-derived data rather than raw LiDAR observations.

Measurements and fitted planes will reference a specific cloud revision, record units and uncertainty, and retain calibration evidence. Detection will propose walls, floors, ceilings, and openings with supporting geometry, confidence, and unresolved assumptions. Reviewers can accept, reject, or correct candidates before the Revit adapter receives approved element specifications.

Each stage creates a versioned artifact linked to its inputs. Coordinate transforms, processing parameters, measurement revisions, review decisions, and Revit element mappings must remain traceable. Changing upstream geometry marks dependent measurements and candidates for review before regeneration.
