import XCTest
@testable import LiDARScan

final class MeasurementTests: XCTestCase {
    func testDistance() {
        XCTAssertEqual(Measurement.distanceMetres(from: .init(0, 0, 0), to: .init(3, 4, 0)), 5, accuracy: 0.0001)
    }
    func testMillimetreDisplay() { XCTAssertEqual(Measurement.display(1.25), "1.250 m  •  1250 mm") }
}
