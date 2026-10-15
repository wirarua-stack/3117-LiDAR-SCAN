import XCTest
import simd
@testable import LiDARScan

final class MeshExportTests: XCTestCase {
    func testCaptureBudgetBoundaries() {
        let budget = CaptureBudget(maximumVertices: 3, maximumTriangles: 2, maximumAnchors: 1)
        XCTAssertTrue(budget.allows(vertices: 3, triangles: 2, anchors: 1))
        XCTAssertFalse(budget.allows(vertices: 4, triangles: 2, anchors: 1))
        XCTAssertFalse(budget.allows(vertices: 3, triangles: 3, anchors: 1))
        XCTAssertFalse(budget.allows(vertices: 3, triangles: 2, anchors: 2))
        XCTAssertFalse(budget.allows(vertices: -1, triangles: 0, anchors: 0))
    }
    private func triangle() -> MeshSample {
        MeshSample(vertices: [.init(SIMD3<Float>(0, 0, 0)), .init(SIMD3<Float>(1, 0, 0)), .init(SIMD3<Float>(0, 1, 0))],
                   triangles: [Triangle(a: 0, b: 1, c: 2)], transform: Matrix4x4(matrix_identity_float4x4))
    }
    func testOBJUsesWorldCoordinatesAndOffsetsAcrossAnchors() throws {
        var moved = triangle()
        var transform = matrix_identity_float4x4
        transform.columns.3.x = 10
        moved.transform = Matrix4x4(transform)
        let text = String(decoding: OBJExporter.data(from: [triangle(), moved]), as: UTF8.self)
        XCTAssertTrue(text.contains("v 10.0 0.0 0.0"))
        XCTAssertTrue(text.contains("f 1 2 3"))
        XCTAssertTrue(text.contains("f 4 5 6"))
    }
    func testArchiveRoundTrip() throws {
        let decoded = try JSONDecoder().decode([MeshSample].self, from: JSONEncoder().encode([triangle()]))
        try decoded[0].validate()
        XCTAssertEqual(decoded[0].vertices.count, 3)
        XCTAssertEqual(decoded[0].triangles[0].c, 2)
    }
    func testPreparedMeshUsesPackedWorldCoordinatesAndIndices() throws {
        var sample = triangle()
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(10, 20, 30, 1)
        sample.transform = Matrix4x4(transform)
        let mesh = try XCTUnwrap(PreparedMesh.prepare([sample]).first)
        XCTAssertEqual(mesh.vertexCount, 3)
        XCTAssertEqual(mesh.triangleCount, 1)
        XCTAssertEqual(mesh.positions.count, 3 * 3 * 4)
        XCTAssertEqual(mesh.indices.count, 3 * 4)
        let xyz = mesh.positions.withUnsafeBytes { bytes in
            (0..<9).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: Float.self) }
        }
        XCTAssertEqual(xyz, [10, 20, 30, 11, 20, 30, 10, 21, 30])
        let indices = mesh.indices.withUnsafeBytes { bytes in
            (0..<3).map { bytes.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self) }
        }
        XCTAssertEqual(indices, [0, 1, 2])
    }
    func testPreparedMeshRejectsInvalidGeometryAndOverflow() {
        var sample = triangle()
        sample.triangles[0].c = 999
        XCTAssertThrowsError(try PreparedMesh.prepare([sample]))
        sample = triangle()
        sample.vertices[1].x = Float.greatestFiniteMagnitude
        sample.transform.values[0] = 2
        XCTAssertThrowsError(try PreparedMesh.prepare([sample]))
    }
    func testPreparedMeshHonorsCancellation() async {
        let worker = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try PreparedMesh.prepare([triangle()])
        }
        do { _ = try await worker.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
    func testPLYHeaderAndWorldCoordinates() throws {
        var moved = triangle()
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4<Float>(10, 20, 30, 1)
        moved.transform = Matrix4x4(transform)
        let text = String(decoding: try PointCloudExporter.data(from: [triangle(), moved], format: .ply), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("ply\nformat ascii 1.0\n"))
        XCTAssertTrue(text.contains("element vertex 6\n"))
        let rows = text.components(separatedBy: "end_header\n")[1].split(separator: "\n")
        XCTAssertEqual(rows.count, 6)
        XCTAssertEqual(rows[3], "10.0 20.0 30.0")
        XCTAssertEqual(rows[4], "11.0 20.0 30.0")
    }
    func testXYZContainsOnlyCoordinateRows() throws {
        let text = String(decoding: try PointCloudExporter.data(from: [triangle()], format: .xyz), as: UTF8.self)
        let rows = text.split(separator: "\n")
        XCTAssertEqual(rows.count, 3)
        for row in rows {
            let columns = row.split(separator: " ")
            XCTAssertEqual(columns.count, 3)
            XCTAssertTrue(columns.allSatisfy { Float($0) != nil })
        }
    }
    func testPointCloudRejectsCorruptGeometry() {
        var sample = triangle()
        sample.vertices[0].x = .nan
        for format in ScanExportFormat.allCases {
            XCTAssertThrowsError(try PointCloudExporter.data(from: [sample], format: format))
        }
    }
    func testEmptyPLYHasZeroVertices() throws {
        let text = String(decoding: try PointCloudExporter.data(from: [], format: .ply), as: UTF8.self)
        XCTAssertTrue(text.contains("element vertex 0\n"))
        XCTAssertTrue(text.hasSuffix("end_header\n"))
    }
    func testRejectsMalformedArchive() {
        var sample = triangle()
        sample.transform.values = []
        XCTAssertThrowsError(try sample.validate())
        sample = triangle()
        sample.triangles = [Triangle(a: 0, b: 1, c: 99)]
        XCTAssertThrowsError(try sample.validate())
    }
}
