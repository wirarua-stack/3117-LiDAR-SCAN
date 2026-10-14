# Implementation status — 2026-10-14

Implemented in source: camera permission and device gate; ARKit mesh capture and removal updates; centered capture reticle; named scan saving with error reporting; archive validation; saved SceneKit model viewer with camera gestures and two-tap distance measurement; OBJ export and sharing with export history.

Source corrections include reading three Float components from ARKit vertex buffers, removing the nonexistent face-buffer offset, matching the reconstruction capability check to `.mesh`, stopping capture when the sheet closes, and protecting a corrupt project index from overwrite.

Automated tests added for archive round-trip, malformed geometry rejection, and OBJ world coordinates/index offsets. These fixtures are synthetic test geometry, never sensor output. Run `swift test` on macOS with Xcode tools. The package isolates geometry/export/measurement code from the iOS application target.

Environment limitation: no Swift compiler, Xcode or physical iPad is available in the Windows workspace. Tests and app compilation have not been executed here. Source/path/XML checks do not establish build success.

Next device validation: open the Xcode project, select signing team, build, scan a measured object, save, reopen, measure two visible surfaces, export/share OBJ and re-import in an independent viewer. Test denied camera access, interrupted sessions and failed storage writes. Compare measurements to an independent reference and record error.

Remaining engineering work: bounded-memory capture, thermal handling, calibrated accuracy, robust interruption/relocalization state, RGB/depth frame recording, point-cloud fusion, editing, rename/duplicate UI, texture mapping and Revit integration. Large archives currently load/export on the main actor and need profiling and background processing before production use. Live raycast measurements use estimated surfaces; saved measurements use mesh intersections. Neither is a verified survey measurement.
