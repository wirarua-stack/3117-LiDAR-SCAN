import Foundation
import simd

enum ScanExportFormat: String, CaseIterable, Identifiable {
    case obj = "OBJ", ply = "PLY", xyz = "XYZ"
    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
    var label: String { self == .obj ? "OBJ mesh" : (self == .ply ? "PLY point cloud + RGB" : "XYZ point cloud (coordinates)") }
}

/// Geometry is in metres in the capture's local, Y-up coordinate frame.
/// Prefer depth-derived clouds; old mesh-only archives retain their mesh-vertex export.
enum PointCloudExporter {
    static func data(from samples: [MeshSample], format: ScanExportFormat) throws -> Data {
        try samples.forEach { try $0.validate() }
        guard format != .obj else {
            let meshes = samples.filter { !$0.triangles.isEmpty }
            guard !meshes.isEmpty else { throw PointCloudExportError.noMesh }
            return OBJExporter.data(from: meshes)
        }
        let clouds = samples.filter { $0.depthSource != nil && !$0.vertices.isEmpty }
        let selected = clouds.isEmpty ? samples : clouds
        let colored = !clouds.isEmpty
        var output = Data()
        if format == .ply {
            let count = selected.reduce(0) { $0 + $1.vertices.count }
            let provenance = colored ? "ARKit sceneDepth + RGB; voxel averaged; not raw depth frames" : "reconstructed mesh vertices, not raw LiDAR"
            let colorProperties = colored ? "property uchar red\nproperty uchar green\nproperty uchar blue\n" : ""
            output.append(Data("""
            ply
            format ascii 1.0
            comment 3117 LiDAR SCAN - \(provenance)
            comment units metres; local ARKit coordinates; Y up; no georeferencing
            element vertex \(count)
            property float x
            property float y
            property float z
            \(colorProperties)end_header

            """.utf8))
        }
        for sample in selected {
            for (index, vertex) in sample.vertices.enumerated() {
                let point = sample.transform.transform(vertex)
                guard point.x.isFinite, point.y.isFinite, point.z.isFinite else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                var line = "\(point.x) \(point.y) \(point.z)"
                if format == .ply, colored, let rgb = sample.colors?[index] { line += " \(rgb.r) \(rgb.g) \(rgb.b)" }
                output.append(Data((line + "\n").utf8))
            }
        }
        return output
    }
}

enum PointCloudExportError: LocalizedError {
    case noMesh
    var errorDescription: String? { "No mesh triangles in this scan. Export the point cloud as PLY or XYZ." }
}

enum OBJExporter {
    static func data(from samples: [MeshSample]) -> Data {
        var lines = ["# 3117 LiDAR SCAN OBJ export"]
        var vertexOffset: UInt32 = 1
        for sample in samples {
            for vertex in sample.vertices {
                let world = sample.transform.transform(vertex)
                lines.append("v \(world.x) \(world.y) \(world.z)")
            }
            for face in sample.triangles { lines.append("f \(face.a + vertexOffset) \(face.b + vertexOffset) \(face.c + vertexOffset)") }
            vertexOffset += UInt32(sample.vertices.count)
        }
        return Data(lines.joined(separator: "\n").utf8)
    }
}
