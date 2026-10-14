import Foundation
import simd

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
