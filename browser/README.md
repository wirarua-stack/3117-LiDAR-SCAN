# 3117 LiDAR Workspace — browser edition

Static, browser-local 3D viewer. No live LiDAR capture, server-side scan upload, georeferencing or Revit generation. Safari/iPad depth acquisition is not provided. Native iPad development remains separate.

Run `node serve.mjs`, then open http://127.0.0.1:4173. Run `node --test test.mjs` for parsing/validation/report tests. No build is required. `dist` contains all runtime assets, including Three.js 0.186.1 under its bundled MIT license.

Import OBJ, ASCII PLY (vertices displayed as points), strict three-column XYZ, native 3117 mesh JSON or a web project backup. Maximum 20 MB, 200,000 points and 400,000 triangles. OBJ polygons are fan-triangulated; non-convex polygons may not render correctly. The unit selector applies to OBJ/PLY/XYZ; native archives and web backups are always metres. Native draft envelopes are not supported. No textures/colour import or LAS/E57.

Pick A/B with measurement mode enabled, name the result, and save. Mesh selection uses ray intersections; point-cloud selection picks the closest hit point within a view-dependent tolerance. Measurements are straight-line distances, not certified survey measurements. Demo geometry and reports are explicitly marked synthetic. Data are stored in IndexedDB on that browser/origin; clearing site data, private browsing or storage eviction can lose projects. Download JSON backups to move between devices/origins. CSV labels are escaped and formula-like labels prefixed. Reports include source and an accuracy caveat.

Verified: six Node tests; local desktop browser rendered the demo, measured a pair, saved it and reopened the project after reload with the result intact. Physical iPad Safari, touch gestures, large files and real scanner data still require validation. A successful hosted deployment does not certify those devices.
