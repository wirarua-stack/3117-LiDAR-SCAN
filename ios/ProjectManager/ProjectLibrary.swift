import Foundation
import SwiftUI

@MainActor
final class ProjectLibrary: ObservableObject {
    @Published private(set) var projects: [ScanProject] = []
    @Published var errorMessage: String?
    private var writable = true
    private let fileURL: URL

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        let folder = directory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("3117LiDARScan", isDirectory: true)
        fileURL = folder.appendingPathComponent("projects.json")
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: fileURL.path) {
                projects = try JSONDecoder().decode([ScanProject].self, from: Data(contentsOf: fileURL))
            }
        } catch { writable = false; errorMessage = error.localizedDescription }
    }
    private func commit(_ updated: [ScanProject]) throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
        projects = updated
    }
    func save(name: String, samples: [MeshSample]) throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        guard samples.contains(where: { !$0.triangles.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
        try samples.forEach { try $0.validate() }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var project = ScanProject(name: cleaned.isEmpty ? "Untitled Scan" : cleaned)
        project.meshFileName = "\(project.id.uuidString).mesh.json"
        try JSONEncoder().encode(samples).write(to: fileURL.deletingLastPathComponent().appendingPathComponent(project.meshFileName!), options: .atomic)
        try commit([project] + projects)
    }
    func rename(_ id: UUID, to name: String) throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw LibraryError.emptyName }
        var updated = projects
        guard let index = updated.firstIndex(where: { $0.id == id }) else { throw LibraryError.missingProject }
        updated[index].name = cleaned
        try commit(updated)
    }
    func duplicate(_ id: UUID) throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        guard let source = projects.first(where: { $0.id == id }) else { throw LibraryError.missingProject }
        let samples = try load(source)
        var copy = ScanProject(name: source.name + " Copy")
        // A duplicate preserves capture provenance, but gets a fresh identity and export history.
        copy.capturedAt = source.capturedAt
        copy.deviceModel = source.deviceModel
        copy.scanType = source.scanType
        copy.coordinateReference = source.coordinateReference
        copy.meshFileName = "\(copy.id.uuidString).mesh.json"
        try JSONEncoder().encode(samples).write(to: fileURL.deletingLastPathComponent().appendingPathComponent(copy.meshFileName!), options: .atomic)
        try commit([copy] + projects)
    }
    func load(_ project: ScanProject) throws -> [MeshSample] {
        guard let name = project.meshFileName, name == URL(fileURLWithPath: name).lastPathComponent else { throw CocoaError(.fileReadCorruptFile) }
        let samples = try JSONDecoder().decode([MeshSample].self, from: Data(contentsOf: fileURL.deletingLastPathComponent().appendingPathComponent(name)))
        try samples.forEach { try $0.validate() }
        return samples
    }
    func delete(at offsets: IndexSet) {
        do {
            var updated = projects
            updated.remove(atOffsets: offsets)
            // Retain geometry files for recovery.
            try commit(updated)
        } catch { errorMessage = error.localizedDescription }
    }
    func export(_ project: ScanProject, format: ScanExportFormat = .obj) throws -> URL {
        guard projects.contains(where: { $0.id == project.id }) else { throw LibraryError.missingProject }
        let samples = try load(project)
        let folder = fileURL.deletingLastPathComponent().appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(project.id.uuidString)-\(UUID().uuidString).\(format.fileExtension)"
        let url = folder.appendingPathComponent(name)
        try PointCloudExporter.data(from: samples, format: format).write(to: url, options: .atomic)
        var updated = projects
        if let index = updated.firstIndex(where: { $0.id == project.id }) {
            updated[index].exportHistory.append(ExportRecord(format: format.rawValue, date: .now, fileName: name))
            try commit(updated)
        }
        return url
    }
}

enum LibraryError: LocalizedError {
    case emptyName, missingProject
    var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a project name."
        case .missingProject: return "This project is no longer in the library."
        }
    }
}
