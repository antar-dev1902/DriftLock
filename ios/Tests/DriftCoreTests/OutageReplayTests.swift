import DriftCore
import XCTest

final class OutageReplayTests: XCTestCase {
    private let trial = OutageTrial(id: "01", start: 0, cut: 10, restore: 15, end: 17)
    private let zero = ENPoint(east: 0, north: 0)

    private func track(yaw: Double = 0, dropAfter: Double = 18) -> [RecordedMotion] {
        (0...180).compactMap { i in
            let t = Double(i) / 10
            guard t <= dropAfter else { return nil }
            return RecordedMotion(time: t, up: SIMD3(0, 0, 1), acceleration: .zero,
                                  yawRate: t >= trial.cut ? yaw : 0)
        }
    }

    private func fixes(outageSpeed: Double = 4, offset: Double = 0) -> [RecordedFix] {
        (0...16).map { i in
            let t = Double(i)
            let masked = t >= trial.cut && t < trial.restore
            return RecordedFix(arrival: t + 0.2, measured: t,
                               point: ENPoint(east: masked ? offset : 0, north: t * 4),
                               speed: masked ? outageSpeed : 4,
                               bearing: masked && offset != 0 ? .pi : 0, accuracy: 5)
        }
    }

    func testReferenceMutationChangesScoreAndLeavesEstimateIdentical() throws {
        let original = try OutageReplay(trial: trial, motion: track(yaw: 0.2), fixes: fixes())
        let altered = try OutageReplay(trial: trial, motion: track(yaw: 0.2),
                                      fixes: fixes(outageSpeed: 25, offset: 70))
        XCTAssertEqual(original.coastPose(at: 14.21), altered.coastPose(at: 14.21))
        XCTAssertEqual(original.baselinePose(at: 14.21), altered.baselinePose(at: 14.21))
        XCTAssertNotEqual(original.metrics.meanDriftlockErrorMeters, altered.metrics.meanDriftlockErrorMeters)
    }

    func testPositiveYawTurnsLeftAndBaselineContinuesNorth() throws {
        let replay = try OutageReplay(trial: trial, motion: track(yaw: 0.2), fixes: fixes())
        let coast = try XCTUnwrap(replay.coastPose(at: 14))
        XCTAssertLessThan(coast.point.east, -5)
        XCTAssertEqual(coast.bearing, -0.8, accuracy: 1e-10)
        XCTAssertEqual(replay.baselinePose(at: 14)?.point, ENPoint(east: 0, north: 56))
        XCTAssertFalse(replay.usesAcceleration)
    }

    func testStaleMotionStopsEstimateAndSuppressesIncompleteSummary() throws {
        let replay = try OutageReplay(trial: trial, motion: track(dropAfter: 12), fixes: fixes())
        XCTAssertNotNil(replay.coastPose(at: 12.3))
        XCTAssertNil(replay.coastPose(at: 12.4))
        XCTAssertEqual(replay.phase(at: 12.4), .unavailable)
        XCTAssertNil(replay.metrics.meanDriftlockErrorMeters)
        XCTAssertEqual(replay.phase(at: 15.3), .recovered)
    }

    func testRecoveryDiscardsFixMeasuredDuringOutageEvenIfArrivingLater() throws {
        let delayed = RecordedFix(arrival: 15.05, measured: 14.9, point: zero, speed: 20,
                                  bearing: 2, accuracy: 5)
        var stream = fixes()
        stream.insert(delayed, at: 15)
        let replay = try OutageReplay(trial: trial, motion: track(), fixes: stream)
        XCTAssertEqual(replay.lastAdmittedFix(at: 15.08)?.measured, 9)
        XCTAssertEqual(replay.phase(at: 15.08), .coasting)
        XCTAssertEqual(replay.resumesAt, 15.2)
        XCTAssertEqual(replay.lastAdmittedFix(at: 15.2)?.measured, 15)
        XCTAssertEqual(replay.metrics.finalErrorAtOutageSeconds ?? 0, 4.9, accuracy: 1e-10)
    }

    func testPostCutMotionAffectsFutureButDoesNotLeakIntoEarlierEstimates() throws {
        let inputs = track()
        let shifted = inputs.map {
            RecordedMotion(time: $0.time, up: $0.up, acceleration: $0.acceleration,
                           yawRate: $0.time >= 12 ? 0.5 : 0)
        }
        let normal = try OutageReplay(trial: trial, motion: inputs, fixes: fixes())
        let edited = try OutageReplay(trial: trial, motion: shifted, fixes: fixes())
        XCTAssertEqual(normal.coastPose(at: 12), edited.coastPose(at: 12))
        XCTAssertNotEqual(normal.coastPose(at: 12.01), edited.coastPose(at: 12.01))
    }
}
