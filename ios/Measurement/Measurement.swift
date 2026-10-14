import Foundation
import simd

enum Measurement {
    static func distanceMetres(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Float { simd_distance(a, b) }
    static func display(_ metres: Float) -> String { String(format: "%.3f m  •  %.0f mm", metres, metres * 1000) }
}
