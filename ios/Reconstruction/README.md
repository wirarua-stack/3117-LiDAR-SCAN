# Reconstruction pipeline

The MVP uses ARKit's on-device scene reconstruction: depth, camera pose, and RGB-derived environment texturing are processed by ARKit into `ARMeshAnchor` updates. The app archives source mesh vertices/faces and transforms. Higher-fidelity fusion, UV texture projection, simplification, and cloud/off-device processing are deliberately future processing stages.
