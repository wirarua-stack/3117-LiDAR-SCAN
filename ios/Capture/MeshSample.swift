import Foundation
import simd

/// Conservative application geometry budget, not a bound on ARKit/GPU memory.
struct CaptureBudget {
    var maximumVertices = 500_000
    var maximumTriangles = 1_000_000
    var maximumAnchors = 2_000
    func allows(vertices: Int, triangles: Int, anchors: Int) -> Bool {
        vertices >= 0 && triangles >= 0 && anchors >= 0 &&
        vertices <= maximumVertices && triangles <= maximumTriangles && anchors <= maximumAnchors
    }
}

struct MeshSample: Codable, Sendable {
    var vertices: [Vector3]
    var triangles: [Triangle]
    var transform: Matrix4x4
    func validate() throws {
        guard transform.values.count == 16, transform.values.allSatisfy({ $0.isFinite }),
              vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
              triangles.allSatisfy({ Int($0.a) < vertices.count && Int($0.b) < vertices.count && Int($0.c) < vertices.count }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}

struct Vector3: Codable, Sendable {
    var x: Float; var y: Float; var z: Float
    init(_ value: SIMD3<Float>) { x = value.x; y = value.y; z = value.z }
    var simd: SIMD3<Float> { SIMD3(x, y, z) }
}

struct Triangle: Codable, Sendable { var a: UInt32; var b: UInt32; var c: UInt32 }

struct Matrix4x4: Codable, Sendable {
    var values: [Float]
    init(_ matrix: simd_float4x4) {
        values = [matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
                  matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
                  matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
                  matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w]
    }
    func transform(_ point: Vector3) -> SIMD4<Float> {
        let matrix = simd_float4x4(SIMD4(values[0], values[1], values[2], values[3]),
                                   SIMD4(values[4], values[5], values[6], values[7]),
                                   SIMD4(values[8], values[9], values[10], values[11]),
                                   SIMD4(values[12], values[13], values[14], values[15]))
        return matrix * SIMD4(point.x, point.y, point.z, 1)
    }
}
