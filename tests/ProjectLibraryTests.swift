import XCTest
import simd
@testable import LiDARScan

final class ProjectLibraryTests: XCTestCase {
    @MainActor
    func testBackgroundOperationsAndFailureRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = ProjectLibrary(directory: directory)
        do {
            try await library.saveInBackground(name: "Empty", samples: [])
            XCTFail("Empty geometry must not be saved")
        } catch { }
        XCTAssertFalse(library.isBusy)
        XCTAssertTrue(library.projects.isEmpty)
        let mesh = MeshSample(vertices: [.init(SIMD3<Float>(0, 0, 0)), .init(SIMD3<Float>(1, 0, 0)), .init(SIMD3<Float>(0, 1, 0))], triangles: [.init(a: 0, b: 1, c: 2)], transform: Matrix4x4(matrix_identity_float4x4))
        try await library.saveInBackground(name: "Async", samples: [mesh])
        let project = try XCTUnwrap(library.projects.first)
        let loaded = try await library.loadInBackground(project)
        XCTAssertEqual(loaded.first?.vertices.count, 3)
        for format in ScanExportFormat.allCases {
            let url = try await library.exportInBackground(project, format: format)
            XCTAssertFalse(try Data(contentsOf: url).isEmpty)
        }
        try await library.duplicateInBackground(project.id)
        XCTAssertFalse(library.isBusy)
        let reopened = ProjectLibrary(directory: directory)
        XCTAssertEqual(reopened.projects.count, 2)
        XCTAssertEqual(reopened.projects.last?.exportHistory.count, 3)
        // Corrupt a fixture archive and ensure failure clears the busy indicator.
        let archive = directory.appendingPathComponent(try XCTUnwrap(project.meshFileName))
        try Data("bad archive".utf8).write(to: archive)
        do { _ = try await library.loadInBackground(project); XCTFail("Must reject corrupt archive") }
        catch { }
        XCTAssertFalse(library.isBusy)
    }

    @MainActor
    func testAllExportFormatsPersistHistoryAndFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = ProjectLibrary(directory: directory)
        let mesh = MeshSample(vertices: [.init(SIMD3<Float>(0, 0, 0)), .init(SIMD3<Float>(1, 0, 0)), .init(SIMD3<Float>(0, 1, 0))], triangles: [.init(a: 0, b: 1, c: 2)], transform: Matrix4x4(matrix_identity_float4x4))
        try library.save(name: "Export fixture", samples: [mesh])
        let project = try XCTUnwrap(library.projects.first)
        for format in ScanExportFormat.allCases {
            let url = try library.export(project, format: format)
            XCTAssertEqual(url.pathExtension, format.fileExtension)
            XCTAssertFalse(try Data(contentsOf: url).isEmpty)
        }
        let reopened = ProjectLibrary(directory: directory)
        XCTAssertEqual(reopened.projects.first?.exportHistory.map(\.format), ["OBJ", "PLY", "XYZ"])
        library.delete(at: IndexSet(integer: 0))
        XCTAssertThrowsError(try library.export(project))
    }

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
