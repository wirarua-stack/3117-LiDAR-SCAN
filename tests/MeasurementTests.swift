import XCTest
@testable import LiDARScan

final class MeasurementTests: XCTestCase {
    func testDistance() {
        XCTAssertEqual(Measurement.distanceMetres(from: .init(0, 0, 0), to: .init(3, 4, 0)), 5, accuracy: 0.0001)
    }
    func testMillimetreDisplay() { XCTAssertEqual(Measurement.display(1.25), "1.250 m  •  1250 mm") }

    func testSelectionPairRestartAndClear() {
        var selection = MeasurementSelection()
        XCTAssertNil(selection.distance)
        XCTAssertTrue(selection.select(.init(0, 0, 0)))
        XCTAssertNil(selection.distance)
        XCTAssertTrue(selection.select(.init(3, 4, 0)))
        XCTAssertEqual(selection.distance, 5)
        XCTAssertTrue(selection.select(.init(1, 2, 3)))
        XCTAssertEqual(selection.points.count, 1)
        XCTAssertNil(selection.distance)
        selection.clear()
        XCTAssertTrue(selection.points.isEmpty)
    }

    func testInvalidSelectionDoesNotChangeEndpoints() {
        var selection = MeasurementSelection()
        selection.select(.init(0, 0, 0))
        XCTAssertFalse(selection.select(.init(.nan, 0, 0)))
        XCTAssertFalse(selection.select(.init(.infinity, 0, 0)))
        XCTAssertFalse(selection.select(.init(Float.greatestFiniteMagnitude, 0, 0)))
        XCTAssertEqual(selection.points.count, 1)
        XCTAssertTrue(selection.select(.init(0, 0, 0)))
        XCTAssertEqual(selection.distance, 0)
    }
}
