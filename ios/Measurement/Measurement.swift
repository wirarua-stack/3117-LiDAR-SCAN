import Foundation
import simd

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
