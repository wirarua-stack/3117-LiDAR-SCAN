import Foundation
import SwiftUI

@MainActor
final class ProjectLibrary: ObservableObject {
    @Published private(set) var projects: [ScanProject] = []
    @Published var errorMessage: String?
    @Published private(set) var operation: String?
    @Published private(set) var draftIDs: [UUID] = []
    var isBusy: Bool { operation != nil }
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
        refreshDrafts()
    }
    private func commit(_ updated: [ScanProject]) throws {
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
        projects = updated
    }
    func save(name: String, samples: [MeshSample]) throws {
        guard !isBusy else { throw LibraryError.busy }
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
        guard !isBusy else { throw LibraryError.busy }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw LibraryError.emptyName }
        var updated = projects
        guard let index = updated.firstIndex(where: { $0.id == id }) else { throw LibraryError.missingProject }
        updated[index].name = cleaned
        try commit(updated)
    }
    func duplicate(_ id: UUID) throws {
        guard !isBusy else { throw LibraryError.busy }
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        guard let source = projects.first(where: { $0.id == id }) else { throw LibraryError.missingProject }
        let samples = try load(source)
        var copy = ScanProject(name: source.name + " Copy")
        // A duplicate preserves capture provenance, but gets a fresh identity and export history.
        copy.capturedAt = source.capturedAt
        copy.deviceModel = source.deviceModel
        copy.scanType = source.scanType
        copy.coordinateReference = source.coordinateReference
        copy.savedMeasurements = source.savedMeasurements
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
            guard !isBusy else { throw LibraryError.busy }
            var updated = projects
            updated.remove(atOffsets: offsets)
            // Retain geometry files for recovery.
            try commit(updated)
        } catch { errorMessage = error.localizedDescription }
    }
    func export(_ project: ScanProject, format: ScanExportFormat = .obj) throws -> URL {
        guard !isBusy else { throw LibraryError.busy }
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

    func saveInBackground(name: String, samples: [MeshSample], captureProject: ScanProject? = nil) async throws {
        guard !isBusy else { throw LibraryError.busy }
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        operation = "Saving scan…"
        defer { operation = nil }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var project = captureProject ?? ScanProject(name: cleaned.isEmpty ? "Untitled Scan" : cleaned)
        project.name = cleaned.isEmpty ? "Untitled Scan" : cleaned
        // Recovery is idempotent if the app stopped after committing metadata but before draft cleanup.
        if projects.contains(where: { $0.id == project.id }) {
            try removeDraft(project.id)
            return
        }
        project.meshFileName = "\(project.id.uuidString).mesh.json"
        let url = fileURL.deletingLastPathComponent().appendingPathComponent(project.meshFileName!)
        try await Task.detached(priority: .userInitiated) {
            guard samples.contains(where: { !$0.triangles.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
            try samples.forEach { try $0.validate() }
            try JSONEncoder().encode(samples).write(to: url, options: .atomic)
        }.value
        // Merge with current metadata only after the archive has been safely written.
        try commit([project] + projects)
        // A failed cleanup must not turn a successful project commit into an apparent failed save.
        do { try removeDraft(project.id) }
        catch { errorMessage = "Project saved, but draft cleanup failed: \(error.localizedDescription)" }
    }

    private var draftsFolder: URL { fileURL.deletingLastPathComponent().appendingPathComponent("Drafts", isDirectory: true) }
    private func draftURL(_ id: UUID) -> URL { draftsFolder.appendingPathComponent("\(id.uuidString).json") }
    private func refreshDrafts() {
        guard FileManager.default.fileExists(atPath: draftsFolder.path) else { draftIDs = []; return }
        do {
            draftIDs = try FileManager.default.contentsOfDirectory(at: draftsFolder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .compactMap { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) }
                .sorted { $0.uuidString < $1.uuidString }
        } catch { errorMessage = "Cannot list recovery drafts: \(error.localizedDescription)" }
    }
    private func removeDraft(_ id: UUID) throws {
        let url = draftURL(id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        refreshDrafts()
    }
    func discardDraft(_ id: UUID) throws {
        guard !isBusy else { throw LibraryError.busy }
        try removeDraft(id)
    }
    func checkpoint(project: ScanProject, samples: [MeshSample]) async throws {
        guard !isBusy else { throw LibraryError.busy }
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        operation = "Saving recovery draft…"
        defer { operation = nil }
        let draft = ScanDraft(project: project, savedAt: .now, samples: samples)
        let folder = draftsFolder
        let url = draftURL(project.id)
        try await Task.detached(priority: .utility) {
            try draft.validate(expectedID: project.id)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // Single atomic envelope: metadata and geometry always refer to the same checkpoint.
            try JSONEncoder().encode(draft).write(to: url, options: .atomic)
        }.value
        refreshDrafts()
    }
    func recoverDraft(_ id: UUID) async throws {
        guard !isBusy else { throw LibraryError.busy }
        operation = "Reading recovery draft…"
        let url = draftURL(id)
        let draft: ScanDraft
        do {
            draft = try await Task.detached(priority: .userInitiated) {
                let value = try JSONDecoder().decode(ScanDraft.self, from: Data(contentsOf: url))
                try value.validate(expectedID: id)
                return value
            }.value
        } catch { operation = nil; throw error }
        operation = nil
        try await saveInBackground(name: draft.project.name, samples: draft.samples, captureProject: draft.project)
    }

    func loadInBackground(_ project: ScanProject) async throws -> [MeshSample] {
        guard !isBusy else { throw LibraryError.busy }
        operation = "Loading model…"
        defer { operation = nil }
        let url = try archiveURL(project)
        return try await Task.detached(priority: .userInitiated) { try ArchiveIO.load(url) }.value
    }

    func exportInBackground(_ project: ScanProject, format: ScanExportFormat) async throws -> URL {
        guard !isBusy else { throw LibraryError.busy }
        guard writable, projects.contains(where: { $0.id == project.id }) else { throw LibraryError.missingProject }
        operation = "Exporting \(format.rawValue)…"
        defer { operation = nil }
        let source = try archiveURL(project)
        let folder = fileURL.deletingLastPathComponent().appendingPathComponent("Exports", isDirectory: true)
        let name = "\(project.id.uuidString)-\(UUID().uuidString).\(format.fileExtension)"
        let url = folder.appendingPathComponent(name)
        try await Task.detached(priority: .userInitiated) {
            let samples = try ArchiveIO.load(source)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try PointCloudExporter.data(from: samples, format: format).write(to: url, options: .atomic)
        }.value
        var updated = projects
        guard let index = updated.firstIndex(where: { $0.id == project.id }) else { throw LibraryError.missingProject }
        updated[index].exportHistory.append(ExportRecord(format: format.rawValue, date: .now, fileName: name))
        try commit(updated)
        return url
    }

    func duplicateInBackground(_ id: UUID) async throws {
        guard !isBusy else { throw LibraryError.busy }
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        guard let source = projects.first(where: { $0.id == id }) else { throw LibraryError.missingProject }
        operation = "Duplicating scan…"
        defer { operation = nil }
        var copy = ScanProject(name: source.name + " Copy")
        copy.capturedAt = source.capturedAt; copy.deviceModel = source.deviceModel
        copy.scanType = source.scanType; copy.coordinateReference = source.coordinateReference
        copy.savedMeasurements = source.savedMeasurements
        copy.meshFileName = "\(copy.id.uuidString).mesh.json"
        let sourceURL = try archiveURL(source)
        let destination = try archiveURL(copy)
        try await Task.detached(priority: .userInitiated) {
            _ = try ArchiveIO.load(sourceURL)
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        }.value
        try commit([copy] + projects)
    }

    private func archiveURL(_ project: ScanProject) throws -> URL {
        guard let name = project.meshFileName, !name.isEmpty,
              name == URL(fileURLWithPath: name).lastPathComponent else { throw CocoaError(.fileReadCorruptFile) }
        return fileURL.deletingLastPathComponent().appendingPathComponent(name)
    }

    func addMeasurement(_ item: SavedMeasurement, to projectID: UUID) throws {
        guard !isBusy else { throw LibraryError.busy }
        try item.validate()
        var updated = projects
        guard let index = updated.firstIndex(where: { $0.id == projectID }) else { throw LibraryError.missingProject }
        var items = updated[index].savedMeasurements ?? []
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
        updated[index].savedMeasurements = items
        try commit(updated)
    }

    func exportMeasurements(_ projectID: UUID) async throws -> URL {
        guard !isBusy else { throw LibraryError.busy }
        guard writable else { throw CocoaError(.fileWriteNoPermission) }
        guard let project = projects.first(where: { $0.id == projectID }) else { throw LibraryError.missingProject }
        operation = "Exporting measurement report…"
        defer { operation = nil }
        let folder = fileURL.deletingLastPathComponent().appendingPathComponent("Exports", isDirectory: true)
        let name = "\(projectID.uuidString)-measurements-\(UUID().uuidString).csv"
        let url = folder.appendingPathComponent(name)
        try await Task.detached(priority: .userInitiated) {
            let data = try MeasurementCSV.data(project: project)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }.value
        var updated = projects
        guard let index = updated.firstIndex(where: { $0.id == projectID }) else { throw LibraryError.missingProject }
        updated[index].exportHistory.append(ExportRecord(format: "Measurement CSV", date: .now, fileName: name))
        try commit(updated)
        return url
    }
}

private enum ArchiveIO {
    static func load(_ url: URL) throws -> [MeshSample] {
        let samples = try JSONDecoder().decode([MeshSample].self, from: Data(contentsOf: url))
        try samples.forEach { try $0.validate() }
        return samples
    }
}

enum LibraryError: LocalizedError {
    case emptyName, missingProject, busy
    var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter a project name."
        case .missingProject: return "This project is no longer in the library."
        case .busy: return "Wait for the current file operation to finish."
        }
    }
}
