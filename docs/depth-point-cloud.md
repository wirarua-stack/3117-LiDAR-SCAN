# Native depth + RGB point cloud

## Scope

The iPad app now has a source implementation of **scan real space → accumulate colored points → save/reopen → export PLY/XYZ**, alongside the existing ARKit mesh. It requires a physical device supporting both mesh scene reconstruction and sceneDepth, camera permission, and a signed native app. It does not make Safari a LiDAR scanner, and does not imply that the unsigned CI artifact is installable. No physical iPad validation has been completed for this pipeline.

The browser edition remains an imported-file viewer. It can read the XYZ coordinates from the new ASCII PLY files, but currently ignores PLY RGB. The browser is not changed or republished by this native update.

## Acquisition and coordinates

- Request `ARWorldTrackingConfiguration.frameSemantics.sceneDepth`; check capability before starting.
- Only accept frames with normal camera tracking, at most 5 frames/second and one integration task in flight. Sample every fourth depth pixel in both dimensions. ARKit's depth is already processed sensor output, not raw laser returns.
- Require confidence value 2 (high), finite depth from 0.2 through 5 metres, supported Float32 depth/8-bit confidence/two-plane camera formats, consistent buffer dimensions and adequate row strides. Unsupported or missing buffers are skipped with a capture status message. The 5 m upper bound is a filter, not an accuracy claim.
- Lock buffers for synchronous sampling, honor row padding, and copy value samples; no ARFrame or pixel buffers are retained by the asynchronous accumulator. The adapter bounds sampled frame size to 20,000 candidates.
- Scale `fx, fy, cx, cy` from camera image resolution to depth resolution. Backproject `((u-cx)*z/fx, -(v-cy)*z/fy, -z)`, then apply the camera-to-world transform. Depth and RGB use native sensor orientation, not UI orientation. Units are metres; ARKit local coordinates, Y up, no georeferencing.
- Sample the corresponding native RGB location from Y/CbCr planes. Convert using a BT.601 approximation, with full/video-range handling. This is not color-calibrated; color registration and portrait/landscape behavior require device verification.

Apple references: [scene depth point-cloud sample](https://developer.apple.com/documentation/arkit/displaying-a-point-cloud-using-scene-depth), [ARDepthData](https://developer.apple.com/documentation/arkit/ardepthdata), [sceneDepth frame semantic](https://developer.apple.com/documentation/arkit/arconfiguration/framesemantics-swift.struct/scenedepth).

## Accumulation and limits

World-space points are keyed by floor(position / 0.02 m), including negative coordinates. Each voxel averages position and RGB observations, capping the historical weight at 255. A maximum of 200,000 occupied voxels is retained. An attempted new voxel beyond that limit pauses acquisition and asks the user to save; existing points remain available. Existing mesh, thermal and memory limits also remain active.

This is voxel downsampling/averaging, **not** TSDF, ICP, loop closure, global pose optimization, dynamic-object rejection, or surface meshing of the cloud. ARKit tracking corrections are not retroactively applied to already accumulated world points. Long scans, relocalization, moving objects and reflective/transparent surfaces can produce drift, duplicates, color blur and disagreement with the independently updated mesh. Scan small static areas; start a new scan if alignment is lost. A voxel size of 2 cm does not imply 2 cm measurement accuracy.

The point cap bounds accumulator occupancy, not total app/GPU memory. Snapshots, JSON encoding, prepared buffers and meshes add memory pressure. Checkpointing is best-effort and cannot guarantee completion before iPadOS suspends the app. Raw per-frame depth, confidence and camera images are not saved, so global refusion cannot be performed later from these archives.

## Persistence, viewer and export

Depth samples reuse the existing mesh archive container with optional paired RGB and depth provenance metadata, empty triangles, world coordinates and identity transform. Old archives without those fields still decode. Depth-only scans can save, checkpoint, recover and duplicate. Final save pauses capture and awaits the accepted in-flight depth integration before taking a snapshot.

The saved-model viewer defaults to RGB points when present and can switch to mesh for existing surface measurements. Point nodes are excluded from mesh hit tests. Direct point-cloud measurement picking is not implemented. RGB renders using SceneKit point primitives with bounded screen-space point sizes; visual acceptance remains required.

- **PLY:** prefer depth clouds, include XYZ and RGB, provenance comment; never combine mesh vertices with the depth cloud. Old mesh-only scans export XYZ vertices without RGB.
- **XYZ:** same geometry selection as PLY, exactly three numeric coordinate columns; no RGB or metadata.
- **OBJ:** mesh triangles only; depth-only scans must use PLY/XYZ.

No E57/LAS, Revit-ready BIM model, automatic building detection or survey certification is provided by this update.

## Verification gates

Automated synthetic tests cover projection axes and camera poses, confidence/depth rejection, YCbCr conversion, voxel averaging/negative coordinates/capacity, actor snapshots, colored archive and packed-buffer round trips, legacy decode, export source selection, and depth-only save/recovery/duplicate/export. They do not test real pixel-buffer alignment, ARKit callbacks or GPU presentation.

Before calling this ready for field use:

1. Sign/install on a LiDAR iPad; record model, iPadOS, app commit and free storage. Scan a static measured wall/corner with color targets for 30–60 seconds.
2. Confirm point/frame counters increase during normal tracking; depth sampling skips limited tracking. Inspect color/orientation in portrait and landscape, front/back movement and a 90° turn; reject mirrored, inverted or doubled surfaces.
3. Pause, resume in the same location, save immediately after a frame, reopen and switch cloud/mesh layers. Check counts, colors and local-frame alignment. Deliberately lose tracking and record drift; do not assume corrections are propagated.
4. Export PLY and XYZ, open in an independent point-cloud tool, confirm vertex count/RGB, metre scale and axis conventions against measured references. Record multiple distances and signed/absolute error, rather than asserting an accuracy threshold from voxel size.
5. Test depth-only archives, draft recovery after forced termination, backgrounding, permission denial, limited storage, prolonged capture, device warming and capacity-triggered pause. Record responsiveness and peak memory.
6. Verify legacy mesh-only projects still open, measure, duplicate and export all formats. Browser PLY import should show coordinates but currently does not preserve RGB.
