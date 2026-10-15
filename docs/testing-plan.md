# Testing plan

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
