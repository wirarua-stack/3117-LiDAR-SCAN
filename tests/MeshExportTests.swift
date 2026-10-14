import XCTest
import simd
@testable import LiDARScan

final class MeshExportTests: XCTestCase {
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
    func testRejectsMalformedArchive() {
        var sample = triangle()
        sample.transform.values = []
        XCTAssertThrowsError(try sample.validate())
        sample = triangle()
        sample.triangles = [Triangle(a: 0, b: 1, c: 99)]
        XCTAssertThrowsError(try sample.validate())
    }
}
