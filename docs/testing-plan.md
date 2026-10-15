# Testing plan

## Saved measurements and CSV acceptance

- Open a saved scan, enable Measure surfaces, select A/B, and Save measurement with a Thai label. Close/relaunch the app: Saved measurements must retain label, date and distance; tapping the record must display the same endpoints. Clear measurement must clear only the current selection, not saved records.
- Duplicate the project and check that its measurements are preserved while its project ID changes. Old projects without a measurement field must still open and accept new records.
- Export CSV from Saved measurements and use Share measurement CSV to save a report. Import as UTF-8/comma-delimited into an independent CSV reader; verify Thai text, labels containing commas/quotes/newlines, negative coordinates, metre units and a known distance.
- Test formula-like labels (for example `=1+1` and whitespace-prefixed formulas): textual cells must not execute as spreadsheet formulas. Apostrophe prefixes may appear in readers that treat CSV purely as text.
- Open two projects in succession and verify reports and endpoint recall belong to the selected project. File names and rows must identify that project. Report files are snapshots: later changes require a new export.
- Inject metadata write failure: saving must report failure rather than claim success. CSV export failure must clear the operation indicator. Never use the report as a certified survey result without independent validation.

## Viewer and visible measurement acceptance

- Open a large saved model and check that read/preparation/assembly stage labels appear. Navigate away while preparation or assembly is running: cancelled work must not replace the new project's scene or leave old measurement markers. Profile frame time and peak memory on physical iPad; preparation being off-main is not sufficient evidence of smooth GPU upload.
- With Measure surfaces off, tap/drag/pinch: no endpoints should be created. Enable it and tap two mesh surfaces: cyan A, green B and a line should match the selected world positions. Orbit and zoom to inspect the endpoints from another angle.
- Tap directly over an existing marker: selection must hit only the underlying mesh, not the annotation sphere/line. Tap empty background: retain the previous endpoints and show a no-surface message.
- A third valid tap starts a new pair and removes the previous line. Clear removes both markers and the line. Changing projects must reset measurement mode and selection.
- Compare a known reference length; distinguish straight-line distance from along-surface distance. The markers are visual aids, not survey accuracy guarantees. Closing the viewer discards unsaved selections; explicitly saved records remain. Geometry exports must not contain markers or measurement lines.

## Stability acceptance (physical device required)

- Capture, switch to another app, return: capture must remain paused until Resume; old geometry must remain available to save. Check alignment after relocalization against a reference object; do not accept shifted/duplicated geometry.
- Trigger a session interruption and a session error separately. Interruption allows manual resume; a failed session must require saving and starting a new capture rather than mixing coordinate frames.
- Exercise serious/critical thermal notification and memory-warning handling using development diagnostics; do not deliberately overheat hardware. Thermal pause must refuse Resume until temperature recovers. Memory pressure must require save/new scan.
- Use a reduced CaptureBudget in a development build to reach vertex, triangle and anchor limits. The last accepted geometry must remain intact, and queued callbacks must not mutate it after pause/save.
- During save/load/export/duplicate, check that the operation indicator animates, conflicting library edits are disabled, and errors restore controls. Test storage failure and retry; never report save success until metadata is committed.
- Close the capture screen while the camera permission prompt is outstanding; granting permission afterward must not start a hidden capture.
- Profile memory and UI latency on the oldest supported iPad. The budget limits retained application geometry, not total ARKit/GPU allocations. JSON/export still materialize complete files, and SceneKit scene construction still runs on the main actor.
- Wait for the recovery timestamp, terminate the app through development tools, relaunch and recover the draft. Verify name, original capture date, local coordinates and geometry. Recovery creates a saved model, not a resumed AR session.
- Repeat termination during a subsequent checkpoint: expect either the previous complete snapshot or the new complete snapshot, never a partially decoded model. Repeat before the first checkpoint and acknowledge that there is nothing to recover.
- Save normally: no draft should remain. Simulate termination after project commit but before draft cleanup: recovery must not duplicate or overwrite the committed project. Explicit discard must remove only that capture's draft.
- Test corrupt draft data, wrong UUID/version, full disk, file-write failure and background suspension. Errors must retain the draft and restore controls. An inactive/background checkpoint is best effort, not a guarantee.

## Automated

- Unit-test distance formatting and numeric calculations.
- Unit-test mesh archive JSON encode/decode and OBJ vertex/face indexing.
- Run `swift test` on macOS after selecting the supported Xcode toolchain.

## Physical-device protocol

1. Use a supported iPad Pro and a measured 1–3 m reference object.
2. Build and install from Xcode with a development team; confirm camera permission.
3. Scan in diffuse light, walking slowly with adequate overlap. Record device model, OS, room/light condition and scan duration.
4. Save, reopen, export OBJ, then re-import to an independent mesh viewer.
5. Aim the capture reticle at each end of the reference object and use **Mark point** twice. Compare the resulting point-to-point value against tape or laser measurement. Record absolute and relative error.
6. Repeat for tracking interruption, low texture, long scan, and thermal/memory conditions.

No physical-device test has been executed in this Windows workspace.

## Point-cloud export acceptance

1. Save a short capture, reopen it, and note the displayed vertex count.
2. Select PLY, export, then share/save the file through the system sheet. Import into an independent point-cloud viewer as metres, Y up. The PLY vertex count must equal the app's mesh vertex count.
3. Repeat for XYZ (three numeric columns, no header) and OBJ. Check the same reference endpoints in all formats without automatic scaling or recentering. Mesh-anchor transforms must preserve alignment between anchors.
4. Switch to another project after exporting: the old share link and previous measurement must disappear. Attempt opening an unreadable archive: do not display the previous project's geometry.
5. Start another capture, try Cancel, choose Keep scanning, then save. Start a separate disposable test capture and confirm Discard; verify it was not added to the library. Swiping must not dismiss a capture containing mesh anchors.
6. Record app commit, device/OS, vertex count, file sizes, save/export duration, reference distance and measured error. Mark pass/fail and attach only non-sensitive test data with consent.

These point clouds are reconstructed mesh vertices, with possible duplicate points at anchor boundaries and uneven sampling. They contain no RGB, intensity or geographic coordinates. PLY documents this in comments; XYZ cannot, so preserve these notes alongside the file. Passing format tests does not establish survey accuracy, safe large-site memory usage, or a working Revit pipeline.
