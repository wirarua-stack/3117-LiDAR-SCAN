import Foundation
import SwiftUI

@MainActor
final class ProjectLibrary: ObservableObject {
    @Published private(set) var projects: [ScanProject] = []
    @Published var errorMessage: String?
    private var writable = true
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("3117LiDARScan", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("projects.json")
        do {
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
        guard samples.contains(where: { !$0.triangles.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
        try samples.forEach { try $0.validate() }
        var project = ScanProject(name: name.isEmpty ? "Untitled Scan" : name)
        project.meshFileName = "\(project.id.uuidString).mesh.json"
        try JSONEncoder().encode(samples).write(to: fileURL.deletingLastPathComponent().appendingPathComponent(project.meshFileName!), options: .atomic)
        try commit([project] + projects)
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
    func export(_ project: ScanProject) throws -> URL {
        let samples = try load(project)
        let folder = fileURL.deletingLastPathComponent().appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "\(project.id.uuidString)-\(UUID().uuidString).obj"
        let url = folder.appendingPathComponent(name)
        try OBJExporter.data(from: samples).write(to: url, options: .atomic)
        var updated = projects
        if let index = updated.firstIndex(where: { $0.id == project.id }) {
            updated[index].exportHistory.append(ExportRecord(format: "OBJ", date: .now, fileName: name))
            try commit(updated)
        }
        return url
    }
}
