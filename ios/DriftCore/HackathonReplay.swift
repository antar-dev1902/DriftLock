import Foundation

/// Presentation and evaluation share the same causal replay. Reference fixes are
/// passed to the scorer and the optional evaluation plot, never to this estimator.
public struct HackathonReplay {
    public init() {}

    public func playback(for drive: RecordedDrive) throws -> Data {
        let windows = try drive.trials.map { trial -> PlaybackWindow in
            let (replay, truth) = try split(drive, trial)
            let timeline = stride(from: trial.cut, through: replay.resumesAt ?? trial.restore, by: 0.2)
            func sample(_ point: ENPoint, at time: Double) -> [Double] {
                [time - trial.start, point.east, point.north].map { ($0 * 10_000).rounded() / 10_000 }
            }
            let errors = score(replay, truth)
            let complete = comparable(errors, truth, trial)
            let telemetry = replay.fixes.map { fix in
                [fix.arrival - trial.start, fix.speed, degrees(fix.bearing)]
            } + timeline.compactMap { time in
                replay.coastPose(at: time).map { [time - trial.start, $0.speed, degrees($0.bearing)] }
            }
            // Telemetry uses admitted measurements or the motion-only estimate.
            let motion = telemetry.sorted { $0[0] < $1[0] }
            let parked = replay.lastAdmittedFix(at: trial.cut.nextDown).map { sample($0.point, at: trial.cut) }
            return PlaybackWindow(
                id: trial.id, recordingStart: trial.start, cut: trial.cut - trial.start, restore: trial.restore - trial.start,
                resumes: replay.resumesAt.map { $0 - trial.start }, duration: trial.end - trial.start,
                observed: replay.fixes.map { sample($0.point, at: $0.arrival) },
                withheld: truth.map { sample($0.point, at: $0.arrival) },
                estimate: timeline.compactMap { time in replay.coastPose(at: time).map { sample($0.point, at: time) } },
                baseline: timeline.compactMap { time in replay.baselinePose(at: time).map { sample($0.point, at: time) } },
                lastPosition: parked, motion: motion, errors: errors,
                metrics: TrialMetrics(
                    id: trial.id, method: replay.usesAcceleration ? "gyro + acceleration" : "gyro, held speed",
                    samples: errors.count,
                    meanDriftlockErrorMeters: complete ? summary("DriftLock", errors.map(\.driftlock)).mean_error_m : nil,
                    meanBaselineErrorMeters: complete ? summary("Constant speed / heading", errors.map(\.constant)).mean_error_m : nil,
                    finalDriftlockErrorMeters: complete ? errors.last?.driftlock : nil,
                    finalBaselineErrorMeters: complete ? errors.last?.constant : nil,
                    finalErrorAtOutageSeconds: complete ? errors.last?.seconds : nil
                )
            )
        }
        return try encode(PlaybackPack(title: drive.title, device: drive.device, windows: windows))
    }

    public func benchmark(for drive: RecordedDrive) throws -> Data {
        let lengths = [30, 60, 90]
        let source = drive.sourceURL?.absoluteString ?? "On-device iPhone capture"
        let dataset = drive.sourceURL == nil ? "on-device-iphone" : "cloudpose-austin-dataset1"
        let groups = lengths.map { duration -> BenchmarkGroup in
            let trials = trials(for: drive, seconds: duration)
            let windows = trials.map { trial -> BenchmarkWindow in
                do {
                    let (replay, truth) = try split(drive, trial)
                    let errors = score(replay, truth)
                    let complete = comparable(errors, truth, trial)
                    return BenchmarkWindow(
                        id: trial.id, startSeconds: trial.start,
                        expectedFixes: truth.count, errors: errors,
                        failure: complete ? nil : "Incomplete comparison: motion or reference coverage ended early.",
                        methods: methods(complete ? errors : [])
                    )
                } catch {
                    return BenchmarkWindow(
                        id: trial.id, startSeconds: trial.start, expectedFixes: 0, errors: [],
                        failure: error.localizedDescription, methods: methods([])
                    )
                }
            }
            let accepted = windows.filter { $0.failure == nil }
            return BenchmarkGroup(
                summary: BenchmarkSummary(
                    dataset_id: dataset, tested_sessions: trials.isEmpty ? 0 : 1,
                    outage_seconds: duration, methods: methods(accepted.flatMap(\.errors)),
                    provenance: "Recorded phone motion and withheld phone GNSS. Imposed blackout. \(source)"
                ),
                windows: windows,
                elapsedUnavailable: trials.isEmpty ? "The recording does not contain a full planned window." : nil
            )
        }
        return try encode(BenchmarkPack(groups: groups))
    }

    private func trials(for drive: RecordedDrive, seconds: Int) -> [OutageTrial] {
        if seconds == 30 { return drive.trials }
        let span = Double(seconds + 30) // 20 s lead-in, full outage, 10 s recovery.
        guard let end = drive.motion.last?.time, end >= span else { return [] }
        return stride(from: 0.0, through: end - span, by: span + 10).enumerated().map { index, start in
            OutageTrial(id: String(format: "%02d", index + 1), start: start,
                        cut: start + 20, restore: start + 20 + Double(seconds), end: start + span)
        }
    }

    private func split(_ drive: RecordedDrive, _ trial: OutageTrial) throws -> (OutageReplay, [RecordedFix]) {
        let admissible = drive.fixes.filter {
            $0.arrival < trial.cut || ($0.arrival >= trial.restore && $0.measured >= trial.restore)
        }
        let truth = drive.fixes.filter {
            $0.measured >= trial.cut && $0.measured < trial.restore && $0.arrival <= trial.end
        }
        return (try OutageReplay(trial: trial, motion: drive.motion, fixes: admissible), truth)
    }

    private func score(_ replay: OutageReplay, _ truth: [RecordedFix]) -> [ReplayErrorPoint] {
        guard let parked = replay.lastAdmittedFix(at: replay.trial.cut.nextDown)?.point else { return [] }
        return truth.compactMap { fix in
            guard let estimate = replay.coastPose(at: fix.measured),
                  let constant = replay.baselinePose(at: fix.measured) else { return nil }
            return ReplayErrorPoint(
                seconds: fix.measured - replay.trial.cut,
                availableAt: fix.arrival - replay.trial.start,
                driftlock: estimate.point.distance(to: fix.point),
                constant: constant.point.distance(to: fix.point),
                lastPosition: parked.distance(to: fix.point)
            )
        }
    }

    private func comparable(_ errors: [ReplayErrorPoint], _ truth: [RecordedFix], _ trial: OutageTrial) -> Bool {
        errors.count == truth.count && (errors.last?.seconds ?? -1) >= trial.duration - 1.5
    }

    private func methods(_ errors: [ReplayErrorPoint]) -> [MethodSummary] {
        [summary("DriftLock", errors.map(\.driftlock)),
         summary("Constant speed / heading", errors.map(\.constant)),
         summary("Last known position", errors.map(\.lastPosition))]
    }

    private func summary(_ name: String, _ values: [Double]) -> MethodSummary {
        let sorted = values.sorted()
        let count = sorted.count
        guard count > 0 else {
            return MethodSummary(name: name, sample_count: 0, mean_error_m: nil,
                                 median_error_m: nil, p90_error_m: nil, max_error_m: nil)
        }
        let median = (sorted[(count - 1) / 2] + sorted[count / 2]) / 2
        return MethodSummary(name: name, sample_count: count, mean_error_m: values.reduce(0, +) / Double(count),
                             median_error_m: median, p90_error_m: sorted[Int(ceil(0.9 * Double(count))) - 1],
                             max_error_m: sorted.last)
    }

    private func degrees(_ bearing: Double) -> Double {
        let wrapped = (bearing * 180 / .pi).truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? min(wrapped + 360, Double(360).nextDown) : wrapped
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value) + Data([10])
    }
}

private struct PlaybackPack: Encodable {
    let schema = "driftlock-flutter-playback-v2"
    let title: String
    let device: String
    let windows: [PlaybackWindow]
}

private struct PlaybackWindow: Encodable {
    let id: String
    let recordingStart: Double
    let cut: Double
    let restore: Double
    let resumes: Double?
    let duration: Double
    let observed, withheld, estimate, baseline: [[Double]]
    let lastPosition: [Double]?
    let motion: [[Double]]
    let errors: [ReplayErrorPoint]
    let metrics: TrialMetrics
}

private struct ReplayErrorPoint: Encodable {
    let seconds, availableAt, driftlock, constant, lastPosition: Double
}

private struct BenchmarkPack: Encodable {
    let schema = "driftlock-hackathon-benchmark-v1"
    let groups: [BenchmarkGroup]
}

private struct BenchmarkGroup: Encodable {
    let summary: BenchmarkSummary
    let windows: [BenchmarkWindow]
    let elapsedUnavailable: String?
}

private struct BenchmarkWindow: Encodable {
    let id: String
    let startSeconds: Double
    let expectedFixes: Int
    let errors: [ReplayErrorPoint]
    let failure: String?
    let methods: [MethodSummary]
}

private struct BenchmarkSummary: Encodable {
    let schema = "driftlock.benchmark.v1"
    let dataset_id: String
    let tested_sessions: Int
    let outage_seconds: Int
    let methods: [MethodSummary]
    let provenance: String
}

private struct MethodSummary: Encodable {
    let name: String
    let sample_count: Int
    let mean_error_m, median_error_m, p90_error_m, max_error_m: Double?

    func encode(to encoder: Encoder) throws {
        var target = encoder.container(keyedBy: CodingKeys.self)
        try target.encode(name, forKey: .name)
        try target.encode(sample_count, forKey: .sample_count)
        try target.encode(mean_error_m, forKey: .mean_error_m)
        try target.encode(median_error_m, forKey: .median_error_m)
        try target.encode(p90_error_m, forKey: .p90_error_m)
        try target.encode(max_error_m, forKey: .max_error_m)
    }

    private enum CodingKeys: String, CodingKey {
        case name, sample_count, mean_error_m, median_error_m, p90_error_m, max_error_m
    }
}
