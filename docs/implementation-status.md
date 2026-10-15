# Implementation status — 2026-10-15

New source update: export selector supports OBJ mesh and ASCII PLY/XYZ point clouds derived from reconstructed mesh vertices. Coordinates are transformed into the local capture frame in metres (Y up), not georeferenced. Vertices are not deduplicated or uniformly sampled and contain no RGB, intensity or raw depth. PLY embeds this provenance in its header; XYZ is numeric XYZ rows only. This is not raw LiDAR capture or point-cloud fusion. Export history retains the selected format. The viewer resets stale geometry, share URLs and measurement state when switching projects. Unsaved scans require discard confirmation, including protection against swipe dismissal.

New tests cover PLY headers/counts/world transforms, numeric XYZ rows, empty PLY, corrupt geometry rejection and persistent export history for all formats. Remote verification of this update is pending; hardware testing remains required.

Implemented in source: camera permission and device gate; ARKit mesh capture and removal updates; centered capture reticle; named scan saving with error reporting; archive validation; saved SceneKit model viewer with camera gestures and two-tap distance measurement; OBJ export and sharing with export history.

Source corrections include reading three Float components from ARKit vertex buffers, removing the nonexistent face-buffer offset, matching the reconstruction capability check to `.mesh`, stopping capture when the sheet closes, and protecting a corrupt project index from overwrite.

Automated tests added for archive round-trip, malformed geometry rejection, and OBJ world coordinates/index offsets. These fixtures are synthetic test geometry, never sensor output. Run `swift test` on macOS with Xcode tools. The package isolates geometry/export/measurement code from the iOS application target.

Environment: the Windows workspace still has no local Swift compiler or Xcode. Remote verification is now complete: [GitHub Actions run 38499242569](https://github.com/wirarua-stack/3117-LiDAR-SCAN/actions/runs/38499242569) passed on 2026-10-14 for commit `549c1cb2b8cba8fd0aa2a36397182aee7c6951a3`, using Xcode 16.4. Five unit tests passed with zero failures; Simulator Debug and unsigned iPad Release builds succeeded. App launch, signing, TestFlight and physical LiDAR capture remain unverified.

Next device validation: open the Xcode project, select signing team, build, scan a measured object, save, reopen, measure two visible surfaces, export/share OBJ and re-import in an independent viewer. Test denied camera access, interrupted sessions and failed storage writes. Compare measurements to an independent reference and record error.

Project-library update: long-press a project to rename or duplicate it. Duplicates retain capture date, device and coordinate reference, but have independent IDs, geometry archives and export histories. Capture now displays ARKit tracking feedback. Persistence tests cover reopening renamed/duplicated projects and protecting corrupt indexes from overwrite.

Verification: [run 38499948724](https://github.com/wirarua-stack/3117-LiDAR-SCAN/actions/runs/38499948724) succeeded for commit `03e63cb1bb41387476e26ffee2bdf86acad8fcad`, including the package tests and both app compilations. Touch interaction and LiDAR behavior still require physical-device validation.

Remaining engineering work: bounded-memory capture, thermal handling, calibrated accuracy, robust interruption/relocalization state, RGB/depth frame recording, point-cloud fusion, editing, texture mapping and Revit integration. Large archives currently load/export on the main actor and need profiling and background processing before production use. Live raycast measurements use estimated surfaces; saved measurements use mesh intersections. Neither is a verified survey measurement.
