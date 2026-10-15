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
    var colors: [PointRGB]?
    var depthSource: DepthCloudMetadata?
    var isUsable: Bool { !triangles.isEmpty || (depthSource != nil && !vertices.isEmpty) }
    func validate() throws {
        guard transform.values.count == 16, transform.values.allSatisfy({ $0.isFinite }),
              vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }),
              triangles.allSatisfy({ Int($0.a) < vertices.count && Int($0.b) < vertices.count && Int($0.c) < vertices.count }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let colors, colors.count != vertices.count { throw CocoaError(.fileReadCorruptFile) }
        if let depthSource {
            guard depthSource.version == 1, depthSource.voxelMetres.isFinite, depthSource.voxelMetres > 0,
                  depthSource.frameCount > 0, triangles.isEmpty, colors != nil else { throw CocoaError(.fileReadCorruptFile) }
        }
    }
}

/// Packed CPU geometry, prepared away from the UI; no SceneKit objects cross actors.
struct PreparedMesh: Sendable {
    let positions: Data
    let indices: Data
    let vertexCount: Int
    let triangleCount: Int
    let colors: Data?

    static func prepare(_ samples: [MeshSample]) throws -> [PreparedMesh] {
        try samples.map { sample in
            try Task.checkCancellation()
            try sample.validate()
            var positions: [Float] = []
            positions.reserveCapacity(sample.vertices.count * 3)
            for (index, vertex) in sample.vertices.enumerated() {
                if index % 4096 == 0 { try Task.checkCancellation() }
                let point = sample.transform.transform(vertex)
                guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { throw CocoaError(.fileReadCorruptFile) }
                positions.append(contentsOf: [point.x, point.y, point.z])
            }
            var indices: [UInt32] = []
            indices.reserveCapacity(sample.triangles.count * 3)
            for (index, triangle) in sample.triangles.enumerated() {
                if index % 4096 == 0 { try Task.checkCancellation() }
                indices.append(contentsOf: [triangle.a, triangle.b, triangle.c])
            }
            return PreparedMesh(positions: positions.withUnsafeBufferPointer { Data(buffer: $0) },
                                indices: indices.withUnsafeBufferPointer { Data(buffer: $0) },
                                vertexCount: sample.vertices.count, triangleCount: sample.triangles.count,
                                colors: sample.colors.map { colors in
                                    let packed = colors.flatMap { [Float($0.r) / 255, Float($0.g) / 255, Float($0.b) / 255] }
                                    return packed.withUnsafeBufferPointer { Data(buffer: $0) }
                                })
        }
    }
}

struct PointRGB: Codable, Sendable, Equatable {
    var r: UInt8; var g: UInt8; var b: UInt8
    /// BT.601 approximation, matching ARKit's bi-planar camera feed convention.
    static func yCbCr(y: UInt8, cb: UInt8, cr: UInt8, videoRange: Bool) -> PointRGB {
        let luma = videoRange ? (Float(y) - 16) * 255 / 219 : Float(y)
        let scale: Float = videoRange ? 255 / 224 : 1
        let blue = (Float(cb) - 128) * scale, red = (Float(cr) - 128) * scale
        func byte(_ n: Float) -> UInt8 { UInt8(max(0, min(255, n.rounded()))) }
        return PointRGB(r: byte(luma + 1.402 * red), g: byte(luma - 0.344136 * blue - 0.714136 * red), b: byte(luma + 1.772 * blue))
    }
}

struct DepthCloudMetadata: Codable, Sendable {
    var version = 1
    var source = "ARKit sceneDepth + capturedImage; voxel-averaged world points"
    var voxelMetres: Float
    var frameCount: Int
    var minimumConfidence = 2
    var minimumDepthMetres: Float = 0.2
    var maximumDepthMetres: Float = 5
    var samplingStride = 4
    var maximumFramesPerSecond = 5
    var colorConversion = "BT.601 YCbCr approximation; not color calibrated"
}

struct DepthPixel: Sendable {
    let x: Float; let y: Float; let depth: Float; let confidence: UInt8; let color: PointRGB
}

struct DepthFrameSample: Sendable {
    // Intrinsics scaled to depth-map resolution; pixels and RGB use native sensor orientation.
    let fx: Float; let fy: Float; let cx: Float; let cy: Float
    let cameraToWorld: Matrix4x4
    let pixels: [DepthPixel]
    func worldPoint(_ pixel: DepthPixel) -> SIMD3<Float>? {
        guard fx.isFinite, fy.isFinite, fx > 0, fy > 0, cx.isFinite, cy.isFinite,
              pixel.x.isFinite, pixel.y.isFinite, pixel.depth.isFinite,
              pixel.depth >= 0.2, pixel.depth <= 5, pixel.confidence == 2,
              cameraToWorld.values.count == 16, cameraToWorld.values.allSatisfy(\.isFinite) else { return nil }
        // Image +Y is down and depth +Z is forward; ARKit camera +Y is up and looks along -Z.
        let camera = SIMD3((pixel.x - cx) * pixel.depth / fx, -(pixel.y - cy) * pixel.depth / fy, -pixel.depth)
        let p = cameraToWorld.transform(Vector3(camera))
        guard p.x.isFinite, p.y.isFinite, p.z.isFinite, abs(p.x) < 10_000, abs(p.y) < 10_000, abs(p.z) < 10_000 else { return nil }
        return SIMD3(p.x, p.y, p.z)
    }
}

struct DepthFusion: Sendable {
    private struct Key: Hashable, Sendable { let x: Int; let y: Int; let z: Int }
    private struct Cell: Sendable {
        var position: SIMD3<Float>
        var color: SIMD3<Float>
        var observations: Int
    }
    let voxelMetres: Float
    let maximumPoints: Int
    private var cells: [Key: Cell] = [:]
    private(set) var frameCount = 0
    var count: Int { cells.count }
    init(voxelMetres: Float = 0.02, maximumPoints: Int = 200_000) {
        precondition(voxelMetres.isFinite && voxelMetres >= 0.001 && maximumPoints > 0)
        self.voxelMetres = voxelMetres; self.maximumPoints = maximumPoints
    }
    /// Returns true when a new voxel would exceed the limit. Existing points are retained.
    mutating func integrate(_ frame: DepthFrameSample) -> Bool {
        var reachedLimit = false
        var accepted = false
        for pixel in frame.pixels {
            guard let p = frame.worldPoint(pixel) else { continue }
            let key = Key(x: Int(floor(p.x / voxelMetres)), y: Int(floor(p.y / voxelMetres)), z: Int(floor(p.z / voxelMetres)))
            let rgb = SIMD3(Float(pixel.color.r), Float(pixel.color.g), Float(pixel.color.b))
            if var cell = cells[key] {
                // Cap history weight to avoid overflow and keep the estimate responsive.
                let weight = Float(min(cell.observations, 255))
                cell.position = (cell.position * weight + p) / (weight + 1)
                cell.color = (cell.color * weight + rgb) / (weight + 1)
                cell.observations = min(cell.observations + 1, 256)
                cells[key] = cell
            } else {
                guard cells.count < maximumPoints else { reachedLimit = true; continue }
                cells[key] = Cell(position: p, color: rgb, observations: 1)
            }
            accepted = true
        }
        if accepted { frameCount += 1 }
        return reachedLimit
    }
    func snapshot() -> MeshSample? {
        guard !cells.isEmpty else { return nil }
        let values = Array(cells.values)
        let colors = values.map { cell in
            PointRGB(r: UInt8(max(0, min(255, cell.color.x.rounded()))),
                     g: UInt8(max(0, min(255, cell.color.y.rounded()))),
                     b: UInt8(max(0, min(255, cell.color.z.rounded()))))
        }
        return MeshSample(vertices: values.map { Vector3($0.position) }, triangles: [], transform: Matrix4x4(matrix_identity_float4x4),
                          colors: colors, depthSource: DepthCloudMetadata(voxelMetres: voxelMetres, frameCount: frameCount))
    }
}

actor DepthFusionStore {
    private var fusion = DepthFusion()
    func integrate(_ frame: DepthFrameSample) -> (count: Int, frames: Int, full: Bool) {
        let full = fusion.integrate(frame)
        return (fusion.count, fusion.frameCount, full)
    }
    func snapshot() -> MeshSample? { fusion.snapshot() }
}

struct Vector3: Codable, Sendable, Hashable {
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
