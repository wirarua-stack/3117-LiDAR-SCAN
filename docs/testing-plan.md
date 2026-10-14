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
