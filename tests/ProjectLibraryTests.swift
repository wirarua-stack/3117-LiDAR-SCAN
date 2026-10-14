import XCTest
import simd
@testable import LiDARScan

final class ProjectLibraryTests: XCTestCase {
    @MainActor
    func testRenameDuplicateAndReopenPreserveCapture() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = ProjectLibrary(directory: directory)
        let mesh = MeshSample(vertices: [.init(SIMD3<Float>(0, 0, 0)), .init(SIMD3<Float>(1, 0, 0)), .init(SIMD3<Float>(0, 1, 0))], triangles: [.init(a: 0, b: 1, c: 2)], transform: Matrix4x4(matrix_identity_float4x4))
        try library.save(name: " Original ", samples: [mesh])
        let original = try XCTUnwrap(library.projects.first)
        XCTAssertEqual(original.name, "Original")
        try library.duplicate(original.id)
        let copy = try XCTUnwrap(library.projects.first)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copy.meshFileName, original.meshFileName)
        XCTAssertEqual(copy.capturedAt, original.capturedAt)
        XCTAssertTrue(copy.exportHistory.isEmpty)
        try library.rename(copy.id, to: " Revised ")
        let reopened = ProjectLibrary(directory: directory)
        XCTAssertEqual(reopened.projects.first?.name, "Revised")
        XCTAssertEqual(reopened.projects.last?.name, "Original")
        XCTAssertEqual(try reopened.load(copy).first?.vertices.count, 3)
        XCTAssertThrowsError(try reopened.rename(copy.id, to: "  "))
    }

    @MainActor
    func testCorruptIndexCannotBeOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let index = directory.appendingPathComponent("projects.json")
        let corrupt = Data("invalid JSON".utf8)
        try corrupt.write(to: index)
        let library = ProjectLibrary(directory: directory)
        XCTAssertNotNil(library.errorMessage)
        XCTAssertThrowsError(try library.save(name: "Test", samples: []))
        XCTAssertEqual(try Data(contentsOf: index), corrupt)
    }
}
