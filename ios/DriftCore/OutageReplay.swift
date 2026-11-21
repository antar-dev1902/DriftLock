import Foundation
import simd

public struct ReplayConfig: Encodable, Sendable {
    public let estimator = "driftlock-ios-planar-v1"
    public let maxMotionGapSeconds = 0.35
    public let maxAnchorAgeSeconds = 2.0
    public let minimumSeedSpeedMPS = 2.0
    public let maxSpeedMPS = 65.0
    public let maxAccelerationMPS2 = 6.0
    public let minimumAlignmentPairs = 6
    public let minimumAlignmentSignalMPS2 = 0.30
    public let maxAlignmentResidualMPS2 = 0.70
    public let maxAlignmentBiasMPS2 = 0.60
    public let maxAlignmentYawRate = 0.12
    public let accelerationFilterSeconds = 0.35
}

public struct OutagePose: Equatable, Sendable {
    public let point: ENPoint
    public let speed: Double
    public let bearing: Double

    func advanced(_ dt: Double, acceleration: Double, yaw: Double, maxSpeed: Double) -> Self {
        let newBearing = bearing - yaw * dt
        let newSpeed = min(max(speed + acceleration * dt, 0), maxSpeed)
        let rampTime = acceleration == 0 ? dt : min(dt, (newSpeed - speed) / acceleration)
        let distance = (speed + newSpeed) * 0.5 * rampTime + newSpeed * (dt - rampTime)
        return Self(point: point.advanced(meters: distance, bearing: (bearing + newBearing) * 0.5),
                    speed: newSpeed, bearing: newBearing)
    }
}

private struct Alignment {
    let forward: SIMD3<Double>
    let bias: Double

    static func estimate(motion: [RecordedMotion], fixes: [RecordedFix], config: ReplayConfig) -> Self? {
        guard !motion.isEmpty else { return nil }
        let up = simd_normalize(motion.reduce(SIMD3<Double>.zero) { $0 + $1.up })
        let pairs = zip(fixes, fixes.dropFirst()).compactMap { first, second -> (SIMD3<Double>, Double)? in
            let dt = second.measured - first.measured
            guard (0.5...1.5).contains(dt), min(first.speed, second.speed) >= config.minimumSeedSpeedMPS else {
                return nil
            }
            let samples = motion.filter { $0.time > first.measured && $0.time <= second.measured }
            guard samples.count >= 5,
                  let meanYaw = samples.map(\.yawRate).mean,
                  abs(meanYaw) < config.maxAlignmentYawRate
            else { return nil }
            let accel = samples.reduce(SIMD3<Double>.zero) { $0 + $1.acceleration } / Double(samples.count)
            return (accel - simd_dot(accel, up) * up, (second.speed - first.speed) / dt)
        }
        guard pairs.count >= config.minimumAlignmentPairs, let meanReference = pairs.map(\.1).mean else {
            return nil
        }
        let meanAccel = pairs.reduce(SIMD3<Double>.zero) { $0 + $1.0 } / Double(pairs.count)
        let differences = pairs.map { ($0.0 - meanAccel, $0.1 - meanReference) }
        let signal = sqrt(differences.map { $0.1 * $0.1 }.mean ?? 0)
        let covariance = differences.reduce(SIMD3<Double>.zero) { $0 + $1.0 * $1.1 } / Double(pairs.count)
        guard signal >= config.minimumAlignmentSignalMPS2, simd_length(covariance) > 0.02 else { return nil }
        let forward = simd_normalize(covariance)
        let bias = simd_dot(meanAccel, forward) - meanReference
        let residual = sqrt(differences.map {
            let error = simd_dot($0.0, forward) - $0.1
            return error * error
        }.mean ?? .infinity)
        guard abs(bias) <= config.maxAlignmentBiasMPS2, residual <= config.maxAlignmentResidualMPS2 else {
            return nil
        }
        return Self(forward: forward, bias: bias)
    }
}

private extension Array where Element == Double {
    var mean: Double? { isEmpty ? nil : reduce(0, +) / Double(count) }
}

private struct CoastStep {
    let time: Double
    let pose: OutagePose
    let acceleration: Double
    let yaw: Double
}

public struct ErrorSample: Sendable {
    public let time: Double
    public let driftlock: Double
    public let baseline: Double
}

public struct TrialMetrics: Encodable, Sendable {
    public let id: String
    public let method: String
    public let samples: Int
    public let meanDriftlockErrorMeters: Double?
    public let meanBaselineErrorMeters: Double?
    public let finalDriftlockErrorMeters: Double?
    public let finalBaselineErrorMeters: Double?
    public let finalErrorAtOutageSeconds: Double?
}

public enum ReplayPhase: Equatable {
    case tracking, coasting, unavailable, recovered
}

public struct OutageReplay {
    public static let config = ReplayConfig()
    public let trial: OutageTrial
    public let fixes: [RecordedFix]
    public let resumesAt: Double?
    public let usesAcceleration: Bool
    private let origin: OutagePose
    private let steps: [CoastStep]
    private let coastUntil: Double

    // Estimation accepts post-cut motion only. The masked locations are used exclusively by the
    // scorer/display, except for locating the first fresh fix after the declared restoration time.
    public init(trial: OutageTrial, motion: [RecordedMotion], fixes: [RecordedFix]) throws {
        let config = Self.config
        let warmupFixes = fixes.filter { $0.usable && $0.arrival >= trial.start && $0.arrival < trial.cut }
        guard let anchor = warmupFixes.last,
              (0...config.maxAnchorAgeSeconds).contains(trial.cut - anchor.measured),
              anchor.speed >= config.minimumSeedSpeedMPS
        else { throw ReplayError.missingAnchor }

        self.trial = trial
        self.fixes = fixes.filter { $0.usable && $0.arrival >= trial.start && $0.arrival <= trial.end }
        resumesAt = self.fixes.first { $0.arrival >= trial.restore && $0.measured >= trial.restore }?.arrival
        let alignment = Alignment.estimate(motion: motion.filter { $0.time >= trial.start && $0.time < trial.cut },
                                           fixes: warmupFixes, config: config)
        usesAcceleration = alignment != nil
        let seed = OutagePose(point: anchor.point, speed: anchor.speed, bearing: anchor.bearing)
        let origin = seed.advanced(trial.cut - anchor.measured, acceleration: 0, yaw: 0, maxSpeed: config.maxSpeedMPS)
        self.origin = origin

        let horizon = resumesAt ?? trial.restore
        var priorMotion = motion.last { $0.time <= trial.cut }
        guard let initial = priorMotion, trial.cut - initial.time <= config.maxMotionGapSeconds else {
            steps = []
            coastUntil = trial.cut
            return
        }

        func forwardAcceleration(_ sample: RecordedMotion) -> Double {
            guard let alignment else { return 0 }
            let horizontal = sample.acceleration - simd_dot(sample.acceleration, sample.up) * sample.up
            return min(max(simd_dot(horizontal, alignment.forward) - alignment.bias, -config.maxAccelerationMPS2),
                       config.maxAccelerationMPS2)
        }

        var pose = origin
        var time = trial.cut
        var acceleration = forwardAcceleration(initial)
        var output: [CoastStep] = [CoastStep(time: time, pose: pose, acceleration: acceleration, yaw: initial.yawRate)]
        for next in motion where next.time > trial.cut && next.time <= horizon {
            guard let previous = priorMotion, next.time - previous.time <= config.maxMotionGapSeconds else { break }
            let dt = next.time - time
            pose = pose.advanced(dt, acceleration: acceleration, yaw: previous.yawRate, maxSpeed: config.maxSpeedMPS)
            let weight = 1 - exp(-dt / config.accelerationFilterSeconds)
            acceleration += weight * (forwardAcceleration(next) - acceleration)
            time = next.time
            priorMotion = next
            output.append(CoastStep(time: time, pose: pose, acceleration: acceleration, yaw: next.yawRate))
        }
        steps = output
        coastUntil = min(horizon, (priorMotion?.time ?? trial.cut) + config.maxMotionGapSeconds)
    }

    public func phase(at time: Double) -> ReplayPhase {
        if time < trial.cut { return .tracking }
        if let resumesAt, time >= resumesAt { return .recovered }
        return coastPose(at: time) == nil ? .unavailable : .coasting
    }

    public func coastPose(at time: Double) -> OutagePose? {
        guard time >= trial.cut, time <= coastUntil,
              let index = steps.lastIndex(where: { $0.time <= time }) else { return nil }
        let step = steps[index]
        return step.pose.advanced(time - step.time, acceleration: step.acceleration, yaw: step.yaw,
                                  maxSpeed: Self.config.maxSpeedMPS)
    }

    public func baselinePose(at time: Double) -> OutagePose? {
        guard time >= trial.cut, time <= trial.restore else { return nil }
        return origin.advanced(time - trial.cut, acceleration: 0, yaw: 0, maxSpeed: Self.config.maxSpeedMPS)
    }

    public func lastAdmittedFix(at time: Double) -> RecordedFix? {
        fixes.last { fix in
            fix.arrival <= time && (fix.arrival < trial.cut
                                    || (fix.arrival >= trial.restore && fix.measured >= trial.restore))
        }
    }

    public var hiddenFixes: [RecordedFix] {
        fixes.filter { $0.measured >= trial.cut && $0.measured < trial.restore }
    }

    public var errors: [ErrorSample] {
        hiddenFixes.compactMap { fix in
            guard let tracked = coastPose(at: fix.measured), let baseline = baselinePose(at: fix.measured) else {
                return nil
            }
            return ErrorSample(time: fix.measured, driftlock: tracked.point.distance(to: fix.point),
                               baseline: baseline.point.distance(to: fix.point))
        }
    }

    public var metrics: TrialMetrics {
        let samples = errors
        // Suppress summary comparisons for an incomplete outage, while retaining valid chart samples.
        let complete = !samples.isEmpty && samples.count == hiddenFixes.count
            && (samples.last?.time ?? trial.cut) >= trial.restore - 1.5
        return TrialMetrics(id: trial.id, method: usesAcceleration ? "gyro + acceleration" : "gyro, held speed",
                            samples: samples.count,
                            meanDriftlockErrorMeters: complete ? samples.map(\.driftlock).mean : nil,
                            meanBaselineErrorMeters: complete ? samples.map(\.baseline).mean : nil,
                            finalDriftlockErrorMeters: complete ? samples.last?.driftlock : nil,
                            finalBaselineErrorMeters: complete ? samples.last?.baseline : nil,
                            finalErrorAtOutageSeconds: complete ? samples.last.map { $0.time - trial.cut } : nil)
    }
}
