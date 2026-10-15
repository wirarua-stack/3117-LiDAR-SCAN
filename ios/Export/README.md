# Export

The native share sheet supports OBJ mesh, ASCII PLY point cloud and XYZ coordinates. When a depth-derived cloud is present, PLY/XYZ select it without mixing in mesh vertices. PLY includes uchar red/green/blue; XYZ contains only XYZ rows. Legacy mesh-only archives retain uncolored vertex export. OBJ selects triangles only and reports an error for depth-only scans. All coordinates are metres in the local Y-up capture frame, without georeferencing.

Exports are not BIM models or raw depth frame recordings. Independent re-import and physical accuracy acceptance remain pending. See [depth pipeline](../../docs/depth-point-cloud.md).
