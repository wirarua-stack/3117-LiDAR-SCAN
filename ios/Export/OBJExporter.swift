import Foundation
import simd

enum ScanExportFormat: String, CaseIterable, Identifiable {
    case obj = "OBJ", ply = "PLY", xyz = "XYZ"
    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
    var label: String { self == .obj ? "OBJ mesh" : "\(rawValue) point cloud (mesh vertices)" }
}

/// Geometry is in metres in the capture's local, Y-up coordinate frame.
/// PLY/XYZ contain reconstructed mesh vertices, not raw depth measurements.
enum PointCloudExporter {
    static func data(from samples: [MeshSample], format: ScanExportFormat) throws -> Data {
        try samples.forEach { try $0.validate() }
        guard format != .obj else { return OBJExporter.data(from: samples) }
        var output = Data()
        if format == .ply {
            let count = samples.reduce(0) { $0 + $1.vertices.count }
            output.append(Data("""
            ply
            format ascii 1.0
            comment 3117 LiDAR SCAN - reconstructed mesh vertices, not raw LiDAR
            comment units metres; local ARKit coordinates; Y up; no georeferencing
            element vertex \(count)
            property float x
            property float y
            property float z
            end_header

            """.utf8))
        }
        for sample in samples {
            for vertex in sample.vertices {
                let point = sample.transform.transform(vertex)
                guard point.x.isFinite, point.y.isFinite, point.z.isFinite else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                output.append(Data("\(point.x) \(point.y) \(point.z)\n".utf8))
            }
        }
        return output
    }
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
