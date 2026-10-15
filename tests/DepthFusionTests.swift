import XCTest
import simd
@testable import LiDARScan

final class DepthFusionTests: XCTestCase {
    private let red = PointRGB(r: 255, g: 0, b: 0)
    private func pixel(_ x: Float = 0, _ y: Float = 0, depth: Float = 1, confidence: UInt8 = 2, color: PointRGB? = nil) -> DepthPixel {
        DepthPixel(x: x, y: y, depth: depth, confidence: confidence, color: color ?? red)
    }
    private func frame(_ pixels: [DepthPixel], transform: simd_float4x4 = matrix_identity_float4x4) -> DepthFrameSample {
        DepthFrameSample(fx: 1000, fy: 1000, cx: 0, cy: 0, cameraToWorld: Matrix4x4(transform), pixels: pixels)
    }
    private func cloud() throws -> MeshSample {
        var fusion = DepthFusion()
        _ = fusion.integrate(frame([pixel()]))
        return try XCTUnwrap(fusion.snapshot())
    }

    func testProjectionUsesScaledIntrinsicsAndARKitAxes() throws {
        // Full-resolution intrinsics (1000,2000,100,200), scaled by 0.1 for depth.
        let f = DepthFrameSample(fx: 100, fy: 200, cx: 10, cy: 20, cameraToWorld: Matrix4x4(matrix_identity_float4x4), pixels: [])
        XCTAssertEqual(try XCTUnwrap(f.worldPoint(pixel(60, 120, depth: 2))), SIMD3<Float>(1, -1, -2))
        XCTAssertEqual(try XCTUnwrap(f.worldPoint(pixel(10, 20, depth: 2))), SIMD3<Float>(0, 0, -2))
    }

    func testCameraRotationAndTranslationProduceWorldCoordinates() throws {
        var transform = simd_float4x4(simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0)))
        transform.columns.3 = SIMD4<Float>(10, 20, 30, 1)
        let p = try XCTUnwrap(frame([], transform: transform).worldPoint(pixel(depth: 2)))
        XCTAssertEqual(p.x, 8, accuracy: 0.00001)
        XCTAssertEqual(p.y, 20, accuracy: 0.00001)
        XCTAssertEqual(p.z, 30, accuracy: 0.00001)
    }

    func testRejectsLowConfidenceInvalidRangeAndInvalidTransforms() {
        let f = frame([])
        for z in [Float.nan, .infinity, -1, 0, 0.199, 5.001] { XCTAssertNil(f.worldPoint(pixel(depth: z))) }
        XCTAssertNotNil(f.worldPoint(pixel(depth: 0.2)))
        XCTAssertNotNil(f.worldPoint(pixel(depth: 5)))
        for c in [UInt8(0), 1, 3, 255] { XCTAssertNil(f.worldPoint(pixel(confidence: c))) }
        XCTAssertNil(f.worldPoint(pixel(.nan)))
        var bad = Matrix4x4(matrix_identity_float4x4)
        bad.values = []
        XCTAssertNil(DepthFrameSample(fx: 1, fy: 1, cx: 0, cy: 0, cameraToWorld: bad, pixels: []).worldPoint(pixel()))
        XCTAssertNil(DepthFrameSample(fx: 0, fy: 1, cx: 0, cy: 0, cameraToWorld: f.cameraToWorld, pixels: []).worldPoint(pixel()))
        var far = matrix_identity_float4x4
        far.columns.3.x = 20_000
        XCTAssertNil(frame([], transform: far).worldPoint(pixel()))
    }

    func testColorConversionSupportsFullAndVideoRangeAndClamps() {
        XCTAssertEqual(PointRGB.yCbCr(y: 0, cb: 128, cr: 128, videoRange: false), PointRGB(r: 0, g: 0, b: 0))
        XCTAssertEqual(PointRGB.yCbCr(y: 255, cb: 128, cr: 128, videoRange: false), PointRGB(r: 255, g: 255, b: 255))
        XCTAssertEqual(PointRGB.yCbCr(y: 16, cb: 128, cr: 128, videoRange: true), PointRGB(r: 0, g: 0, b: 0))
        XCTAssertEqual(PointRGB.yCbCr(y: 235, cb: 128, cr: 128, videoRange: true), PointRGB(r: 255, g: 255, b: 255))
        XCTAssertEqual(PointRGB.yCbCr(y: 76, cb: 85, cr: 255, videoRange: false), PointRGB(r: 254, g: 0, b: 0))
        XCTAssertEqual(PointRGB.yCbCr(y: 255, cb: 255, cr: 255, videoRange: false).r, 255)
    }

    func testVoxelFusionMergesFramesAndAveragesColors() throws {
        var fusion = DepthFusion()
        XCTAssertFalse(fusion.integrate(frame([pixel(1, -1)])))
        var pose = matrix_identity_float4x4
        pose.columns.3.x = 0.002
        XCTAssertFalse(fusion.integrate(frame([pixel(1, -1, color: PointRGB(r: 0, g: 0, b: 255))], transform: pose)))
        XCTAssertEqual(fusion.count, 1)
        XCTAssertEqual(fusion.frameCount, 2)
        let sample = try XCTUnwrap(fusion.snapshot())
        try sample.validate()
        XCTAssertEqual(sample.vertices[0].x, 0.002, accuracy: 0.000001)
        XCTAssertEqual(sample.colors, [PointRGB(r: 128, g: 0, b: 128)])
        XCTAssertTrue(sample.triangles.isEmpty)
        XCTAssertEqual(sample.depthSource?.frameCount, 2)
        XCTAssertEqual(sample.depthSource?.voxelMetres, 0.02)
    }

    func testNegativeVoxelsAndCapacityRetainExistingPoints() throws {
        var fusion = DepthFusion(maximumPoints: 2)
        XCTAssertNil(fusion.snapshot())
        XCTAssertFalse(fusion.integrate(frame([pixel(-1), pixel(1)])))
        XCTAssertEqual(fusion.count, 2) // floor, not truncation toward zero
        XCTAssertTrue(fusion.integrate(frame([pixel(100)])))
        XCTAssertEqual(fusion.count, 2)
        XCTAssertEqual(fusion.frameCount, 1)
        XCTAssertFalse(fusion.integrate(frame([pixel(1, color: PointRGB(r: 0, g: 0, b: 255))])))
        XCTAssertEqual(fusion.frameCount, 2)
        XCTAssertFalse(fusion.integrate(frame([pixel(depth: .nan)])))
        XCTAssertEqual(fusion.frameCount, 2)
    }

    func testColoredArchiveAndPreparedBuffersRoundTrip() throws {
        let sample = try cloud()
        let decoded = try JSONDecoder().decode(MeshSample.self, from: JSONEncoder().encode(sample))
        try decoded.validate()
        XCTAssertTrue(decoded.isUsable)
        XCTAssertEqual(decoded.colors, [red])
        let packed = try XCTUnwrap(PreparedMesh.prepare([decoded]).first)
        XCTAssertEqual(packed.triangleCount, 0)
        XCTAssertTrue(packed.indices.isEmpty)
        let rgb = try XCTUnwrap(packed.colors).withUnsafeBytes { bytes in
            (0..<3).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
        }
        XCTAssertEqual(rgb, [1, 0, 0])
        var bad = sample
        bad.colors = []
        XCTAssertThrowsError(try bad.validate())
        bad.colors = nil
        XCTAssertThrowsError(try bad.validate())
        bad = sample
        bad.depthSource?.version = 999
        XCTAssertThrowsError(try bad.validate())
    }

    func testLegacyArchiveWithoutNewFieldsStillDecodes() throws {
        let json = """
        {"vertices":[],"triangles":[],"transform":{"values":[1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]}}
        """
        let sample = try JSONDecoder().decode(MeshSample.self, from: Data(json.utf8))
        try sample.validate()
        XCTAssertNil(sample.colors)
        XCTAssertNil(sample.depthSource)
        XCTAssertFalse(sample.isUsable)
    }

    func testExportPrefersDepthRGBAndDoesNotMixMeshVertices() throws {
        let sample = try cloud()
        let mesh = MeshSample(vertices: [.init(.zero), .init(SIMD3<Float>(1, 0, 0)), .init(SIMD3<Float>(0, 1, 0))],
                              triangles: [.init(a: 0, b: 1, c: 2)], transform: Matrix4x4(matrix_identity_float4x4))
        let ply = String(decoding: try PointCloudExporter.data(from: [mesh, sample], format: .ply), as: UTF8.self)
        XCTAssertTrue(ply.contains("element vertex 1\n"))
        XCTAssertTrue(ply.contains("property uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n"))
        XCTAssertTrue(ply.contains("ARKit sceneDepth + RGB"))
        let rows = ply.components(separatedBy: "end_header\n")[1].split(separator: "\n")
        XCTAssertEqual(rows.count, 1)
        let values = rows[0].split(separator: " ").compactMap { Float($0) }
        XCTAssertEqual(values, [0, 0, -1, 255, 0, 0])
        let xyz = String(decoding: try PointCloudExporter.data(from: [mesh, sample], format: .xyz), as: UTF8.self)
        XCTAssertEqual(xyz.split(separator: "\n").count, 1)
        XCTAssertEqual(xyz.split(whereSeparator: { $0.isWhitespace }).compactMap { Float($0) }, [0, 0, -1])
        let obj = String(decoding: try PointCloudExporter.data(from: [sample, mesh], format: .obj), as: UTF8.self)
        XCTAssertEqual(obj.split(separator: "\n").filter { $0.hasPrefix("v ") }.count, 3)
        XCTAssertTrue(obj.contains("f 1 2 3"))
        XCTAssertThrowsError(try PointCloudExporter.data(from: [sample], format: .obj))
    }

    @MainActor
    func testDepthOnlySaveCheckpointRecoverDuplicateAndExport() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = ProjectLibrary(directory: directory)
        let sample = try cloud()
        try library.save(name: "Depth only", samples: [sample])
        XCTAssertEqual(library.projects.first?.scanType, "LiDAR depth + RGB point cloud")
        let draft = ScanProject(name: "Depth recovery")
        try await library.checkpoint(project: draft, samples: [sample])
        let reopened = ProjectLibrary(directory: directory)
        try await reopened.recoverDraft(draft.id)
        let saved = try XCTUnwrap(reopened.projects.first)
        XCTAssertEqual(saved.id, draft.id)
        XCTAssertEqual(saved.scanType, "LiDAR depth + RGB point cloud")
        XCTAssertEqual(try reopened.load(saved).first?.colors, [red])
        XCTAssertTrue(reopened.draftIDs.isEmpty)
        try await reopened.duplicateInBackground(saved.id)
        let copy = try XCTUnwrap(reopened.projects.first)
        XCTAssertEqual(try reopened.load(copy).first?.depthSource?.frameCount, 1)
        let url = try await reopened.exportInBackground(copy, format: .ply)
        XCTAssertTrue(String(decoding: try Data(contentsOf: url), as: UTF8.self).contains("property uchar red"))
    }

    func testActorStoreSnapshotIncludesAcceptedFrame() async throws {
        let store = DepthFusionStore()
        let state = await store.integrate(frame([pixel()]))
        XCTAssertEqual(state.count, 1)
        XCTAssertFalse(state.full)
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot?.depthSource?.frameCount, 1)
    }
}
