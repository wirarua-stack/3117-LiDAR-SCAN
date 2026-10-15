import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ScanProject: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var capturedAt: Date
    var deviceModel: String
    var scanType: String
    var coordinateReference: String
    var meshFileName: String?
    var exportHistory: [ExportRecord]
    // Optional for backward-compatible decoding of projects and recovery drafts created before measurements.
    var savedMeasurements: [SavedMeasurement]?

    init(name: String, meshFileName: String? = nil) {
        id = UUID(); self.name = name; capturedAt = .now
        deviceModel = DeviceInfo.modelIdentifier; scanType = "LiDAR mesh"
        coordinateReference = "ARKit local world origin"; self.meshFileName = meshFileName; exportHistory = []
    }
}

struct ExportRecord: Codable, Hashable, Sendable { let format: String; let date: Date; let fileName: String }

struct ScanDraft: Codable, Sendable {
    var version = 1
    let project: ScanProject
    let savedAt: Date
    let samples: [MeshSample]
    func validate(expectedID: UUID) throws {
        guard version == 1, project.id == expectedID,
              samples.contains(where: { !$0.triangles.isEmpty }) else { throw CocoaError(.fileReadCorruptFile) }
        try samples.forEach { try $0.validate() }
    }
}

enum DeviceInfo {
    static var modelIdentifier: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return "Non-capture test host"
        #endif
    }
}
