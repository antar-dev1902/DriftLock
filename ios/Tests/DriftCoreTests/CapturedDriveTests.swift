import XCTest
@testable import DriftCore

final class CapturedDriveTests: XCTestCase {
    private func captureCSV(mock: Bool = false, clockJump: Bool = false) -> String {
        let initial = CaptureFormat.columns.joined(separator: ",")
        let utc = 1_760_000_000.0
        func row(_ kind: String, time: Double, values: [Int: Double] = [:]) -> String {
            var fields = Array(repeating: "", count: CaptureFormat.columns.count)
            fields[0] = CaptureFormat.version
            fields[1] = kind
            fields[4] = String(500 + time)
            fields[5] = String(utc + time + (clockJump && time > 32 ? 1 : 0))
            for (index, value) in values { fields[index] = String(value) }
            return fields.joined(separator: ",")
        }
        var rows = [initial, row("start_z_vertical", time: 0)]
        for index in 1...615 {
            let time = Double(index) / 10
            rows.append(row("device_motion", time: time, values: [
                2: 500 + time - 0.01, 6: 0, 7: 0, 8: 0, 9: 0, 10: 0, 11: 0, 12: 0, 13: 0, 14: -1
            ]))
            if index.isMultiple(of: 10) {
                rows.append(row("location", time: time, values: [
                    3: utc + time - 0.12, 15: 30 + time * 0.00004, 16: 76, 17: 5,
                    18: 4.4, 20: 0, 22: mock ? 1 : 0, 23: 0
                ]))
            }
        }
        return rows.joined(separator: "\n")
    }

    func testCaptureReplaysOnItsOwnArrivalClock() throws {
        let trace = try RecordedDrive.loadCapture(captureCSV())
        let trial = try XCTUnwrap(trace.trials.first)
        let replay = try OutageReplay(trial: trial, motion: trace.motion, fixes: trace.fixes)
        XCTAssertNil(trace.sourceURL)
        XCTAssertEqual(trace.motion.count, 615)
        XCTAssertEqual(trace.fixes[0].arrival, 1)
        XCTAssertEqual(trace.fixes[0].measured, 0.88, accuracy: 0.000001)
        XCTAssertEqual(replay.metrics.samples, 30)
        XCTAssertEqual(replay.resumesAt, 51)
    }

    func testCaptureRejectsClockJump() {
        XCTAssertThrowsError(try RecordedDrive.loadCapture(captureCSV(clockJump: true))) {
            XCTAssertEqual($0 as? CaptureReplayError, .clockChanged)
        }
    }

    func testCaptureExcludesSimulatedFixes() {
        XCTAssertThrowsError(try RecordedDrive.loadCapture(captureCSV(mock: true))) {
            XCTAssertEqual($0 as? CaptureReplayError, .insufficientData)
        }
    }
}
