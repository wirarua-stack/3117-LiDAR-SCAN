import XCTest
@testable import LiDARScan

final class MeasurementTests: XCTestCase {
    func testSavedMeasurementValidationAndCSV() throws {
        var project = ScanProject(name: "=project")
        let record = try SavedMeasurement(name: "ผนัง, \"A\"\nด้านใน", a: .init(-1, 0, 0), b: .init(2, 4, 0))
        project.savedMeasurements = [record]
        let text = String(decoding: try MeasurementCSV.data(project: project), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("\u{FEFF}project_id,"))
        XCTAssertTrue(text.contains("\"'=project\""))
        XCTAssertTrue(text.contains("\"ผนัง, \"\"A\"\"\nด้านใน\""))
        XCTAssertTrue(text.contains(",m,-1.0,0.0,0.0,2.0,4.0,0.0,5.0,"))
        XCTAssertTrue(text.contains("not_survey_validated"))
        XCTAssertThrowsError(try SavedMeasurement(name: " ", a: .zero, b: .zero))
        XCTAssertThrowsError(try SavedMeasurement(name: "Bad", a: .init(.nan, 0, 0), b: .zero))
    }
    func testCSVNeutralizesFormulaLabelsAndEscapesQuotes() {
        for value in ["=1+1", "+SUM(A1)", "-1+2", "@test", "  =1", "\t=1", "\r=1", "\n=1"] {
            XCTAssertTrue(MeasurementCSV.textCell(value).hasPrefix("\"'"))
        }
        XCTAssertEqual(MeasurementCSV.textCell("A,\"B\""), "\"A,\"\"B\"\"\"")
    }
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
