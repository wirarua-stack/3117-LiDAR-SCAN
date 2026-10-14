import Foundation
import UIKit

struct ScanProject: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let capturedAt: Date
    var deviceModel: String
    var scanType: String
    var coordinateReference: String
    var meshFileName: String?
    var exportHistory: [ExportRecord]

    init(name: String, meshFileName: String? = nil) {
        id = UUID(); self.name = name; capturedAt = .now
        deviceModel = DeviceInfo.modelIdentifier; scanType = "LiDAR mesh"
        coordinateReference = "ARKit local world origin"; self.meshFileName = meshFileName; exportHistory = []
    }
}

struct ExportRecord: Codable, Hashable { let format: String; let date: Date; let fileName: String }

enum DeviceInfo { static var modelIdentifier: String { UIDevice.current.model } }
