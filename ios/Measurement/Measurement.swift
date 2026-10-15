import Foundation
import simd

struct SavedMeasurement: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let a: Vector3
    let b: Vector3
    var distanceMetres: Float { Measurement.distanceMetres(from: a.simd, to: b.simd) }

    init(name: String, a: SIMD3<Float>, b: SIMD3<Float>) throws {
        id = UUID(); createdAt = .now
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.a = Vector3(a); self.b = Vector3(b)
        try validate()
    }
    func validate() throws {
        guard !name.isEmpty, name.count <= 256,
              [a.x, a.y, a.z, b.x, b.y, b.z, distanceMetres].allSatisfy({ $0.isFinite }) else {
            throw MeasurementError.invalidRecord
        }
    }
}

enum MeasurementError: LocalizedError {
    case invalidRecord
    var errorDescription: String? { "Enter a name (1–256 characters) and select two valid mesh points." }
}

enum MeasurementCSV {
    // Quote and escape text, and neutralize spreadsheet formulas including whitespace-prefixed formulas.
    static func textCell(_ value: String) -> String {
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let dangerous = first.map { "=+-@".contains($0) } ?? false
        let safe = dangerous || value.first == "\t" || value.first == "\r" || value.first == "\n" ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    static func data(project: ScanProject) throws -> Data {
        var rows = ["project_id,project_name,measurement_id,label,measured_at_utc,unit,a_x,a_y,a_z,b_x,b_y,b_z,distance_m,coordinate_reference,method,accuracy_status"]
        let dates = ISO8601DateFormatter()
        for item in project.savedMeasurements ?? [] {
            try item.validate()
            let fields = [textCell(project.id.uuidString), textCell(project.name), textCell(item.id.uuidString),
                          textCell(item.name), textCell(dates.string(from: item.createdAt)), "m",
                          String(item.a.x), String(item.a.y), String(item.a.z), String(item.b.x), String(item.b.y), String(item.b.z),
                          String(item.distanceMetres), textCell(project.coordinateReference), "mesh_surface_straight_line", "not_survey_validated"]
            rows.append(fields.joined(separator: ","))
        }
        // UTF-8 BOM helps spreadsheet applications recognize Thai labels.
        return Data(("\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n").utf8)
    }
}

enum Measurement {
    static func distanceMetres(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Float { simd_distance(a, b) }
    static func display(_ metres: Float) -> String { String(format: "%.3f m  •  %.0f mm", metres, metres * 1000) }
}

struct MeasurementSelection {
    private(set) var points: [SIMD3<Float>] = []
    var distance: Float? {
        guard points.count == 2 else { return nil }
        return Measurement.distanceMetres(from: points[0], to: points[1])
    }
    mutating func clear() { points.removeAll() }
    @discardableResult
    mutating func select(_ point: SIMD3<Float>) -> Bool {
        guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { return false }
        if points.count == 1, !Measurement.distanceMetres(from: points[0], to: point).isFinite { return false }
        if points.count == 2 { clear() }
        points.append(point)
        return true
    }
}
