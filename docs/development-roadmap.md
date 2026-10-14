# Development roadmap

The primary product objective is **Scan → Point Cloud → Measurement → Building-element detection → Revit BIM Model**. Prioritize a verified path through these stages for existing-building work.

| Stage | Deliverable | Acceptance gate |
|---|---|---|
| 1. Scan | Offline hardware capture, saved/reopened projects, tracking feedback and source metadata | Xcode build and physical-iPad capture verified; saved geometry reopens and an export re-imports successfully |
| 2. Point Cloud | Depth/pose-based registered cloud, confidence filtering, inspection/crop and PLY interchange | Units and coordinate transforms verified against a known reference; exported points re-import without coordinate or scale changes |
| 3. Measurement | Distance, height, area and plane fitting with uncertainty and calibration records | Repeat captures compared with independently measured dimensions; report error against a tolerance selected for the intended job |
| 4. Building-element detection | Wall, floor, ceiling and opening candidates with confidence, supporting evidence and correction tools | Evaluate against manually annotated test scenes; reviewer confirms or corrects dimensions, levels, openings and relationships |
| 5. Revit BIM Model | C# add-in creates approved editable elements and retains source-to-element mappings | Verify placement, units, levels, types and host relationships in the supported Revit version; repeated import avoids duplicates and reports unsupported candidates |

Current status: mesh-capture source, archive persistence, saved-model viewing, surface measurements and OBJ sharing exist. The capture acceptance gate is still open pending Xcode and physical-device verification. Point-cloud fusion, element detection and Revit generation are planned. See [implementation status](implementation-status.md).

Mesh cleanup, texture mapping and additional formats (STL/USDZ, GLB, E57/LAS and IFC) support this workflow. Their priority follows field validation needs. Dependency and Revit API version compatibility must be checked when implementing each integration.

Product evaluation should track dimensional error, candidate correction rate, time from capture to approved BIM, and effort compared with manual modeling on the same test site. Baselines and targets must come from measured trials; no performance or accuracy target is claimed as achieved.

## Risks

| Risk | Mitigation |
|---|---|
| Device support / tracking loss | Capability gate, status feedback, physical-device test matrix |
| Memory / thermal pressure | Bound capture duration, profile on target devices, process in chunks |
| Dimensional uncertainty | Calibration procedure and captured reference measurements |
| Mesh mistaken for BIM | Explicit workflow separation and mandatory review |
| Export interoperability | Golden-file re-import tests in each receiving tool |
