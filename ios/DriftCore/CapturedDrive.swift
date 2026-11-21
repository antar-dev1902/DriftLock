import Foundation
import simd

public enum CaptureFormat {
    public static let version = "driftlock-ios-capture-v1"
    public static let columns = [
        "schema", "kind", "sample_motion_boot_s", "sample_location_unix_s",
        "receipt_uptime_s", "receipt_unix_s", "ax_mps2", "ay_mps2", "az_mps2", "gx_rad_s", "gy_rad_s", "gz_rad_s",
        "gravity_x_g", "gravity_y_g", "gravity_z_g", "latitude_deg", "longitude_deg", "horizontal_accuracy_m",
        "speed_mps", "speed_accuracy_mps", "course_deg", "course_accuracy_deg", "simulated", "accessory"
    ]
}

public enum CaptureReplayError: LocalizedError {
    case invalidFile, clockChanged, insufficientData

    public var errorDescription: String? {
        switch self {
        case .invalidFile: "This CSV does not match the Driftlock iPhone recording format."
        case .clockChanged: "The recording clock changed during the drive. Record a new session."
        case .insufficientData: "Record at least 60 seconds with a moving GPS fix before the outage."
        }
    }
}

extension RecordedDrive {
    public static func loadCapture(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard let text = String(data: data, encoding: .utf8) else { throw CaptureReplayError.invalidFile }
        return try loadCapture(text)
    }

    static func loadCapture(_ text: String) throws -> Self {
        var rows = text.split(whereSeparator: \.isNewline).makeIterator()
        guard let header = rows.next(), String(header) == CaptureFormat.columns.joined(separator: ","),
              let first = rows.next() else { throw CaptureReplayError.invalidFile }
        let origin = try CaptureRow(first)
        guard ["start_corrected_z_vertical", "start_z_vertical"].contains(origin.kind) else {
            throw CaptureReplayError.invalidFile
        }
        var motion: [RecordedMotion] = []
        var fixes: [RecordedFix] = []
        var originCoordinate: (latitude: Double, longitude: Double)?
        var previousReceipt = origin.uptime
        var previousMotionClock = -Double.infinity

        for line in rows {
            let row = try CaptureRow(line)
            let elapsed = row.uptime - origin.uptime
            guard row.uptime >= previousReceipt, abs((row.unix - origin.unix) - elapsed) <= 0.25 else {
                throw CaptureReplayError.clockChanged
            }
            previousReceipt = row.uptime
            switch row.kind {
            case "device_motion":
                if let prior = motion.last, elapsed <= prior.time { continue }
                guard let source = row.number(2), source > previousMotionClock else {
                    throw CaptureReplayError.clockChanged
                }
                previousMotionClock = source
                motion.append(try row.motion(at: elapsed))
            case "location":
                guard row.number(22) != 1, row.number(23) != 1,
                      let latitude = row.number(15), let longitude = row.number(16),
                      abs(latitude) <= 90, abs(longitude) <= 180 else { continue }
                let projection = originCoordinate ?? (latitude, longitude)
                let fix = row.fix(at: elapsed, point: Self.project(latitude, longitude, relativeTo: projection))
                guard let fix, fix.usable, fix.measured >= 0, fix.measured > (fixes.last?.measured ?? -1) else { continue }
                originCoordinate = projection
                if fixes.last?.arrival == fix.arrival { fixes.removeLast() }
                fixes.append(fix)
            case "raw_accelerometer", "raw_gyroscope":
                break
            default:
                throw CaptureReplayError.invalidFile
            }
        }
        let last = motion.last?.time ?? 0
        guard last >= 60 else { throw CaptureReplayError.insufficientData }
        let trials = stride(from: 0.0, through: last - 60, by: 70).enumerated().compactMap { number, start -> OutageTrial? in
            let trial = OutageTrial(id: String(format: "%02d", number + 1), start: start, cut: start + 20,
                                   restore: start + 50, end: start + 60)
            return (try? OutageReplay(trial: trial, motion: motion, fixes: fixes)) == nil ? nil : trial
        }
        guard !trials.isEmpty else { throw CaptureReplayError.insufficientData }
        return Self(contract: "driftlock-ios-replay-v1", title: "Your iPhone drive", place: "On-device capture",
                    device: "iPhone", recordedOn: Date(timeIntervalSince1970: origin.unix).formatted(date: .abbreviated, time: .omitted),
                    sourceURL: nil, motion: motion, fixes: fixes, trials: trials)
    }

    private static func project(_ latitude: Double, _ longitude: Double,
                                relativeTo origin: (latitude: Double, longitude: Double)) -> ENPoint {
        let phi = origin.latitude * .pi / 180
        let a = 6_378_137.0, e2 = 0.00669437999014
        let w = sqrt(1 - e2 * pow(sin(phi), 2))
        let longitudeDelta = (longitude - origin.longitude + 540).truncatingRemainder(dividingBy: 360) - 180
        return ENPoint(east: longitudeDelta * .pi / 180 * a / w * cos(phi),
                       north: (latitude - origin.latitude) * .pi / 180 * a * (1 - e2) / pow(w, 3))
    }
}

private struct CaptureRow {
    let fields: [Substring]
    let kind: Substring
    let uptime: Double
    let unix: Double

    init(_ line: Substring) throws {
        let fields = line.split(separator: ",", omittingEmptySubsequences: false)
        guard fields.count == CaptureFormat.columns.count, fields[0] == CaptureFormat.version,
              let uptime = Double(fields[4]), let unix = Double(fields[5]),
              uptime.isFinite, uptime >= 0, unix.isFinite, unix > 0 else { throw CaptureReplayError.invalidFile }
        self.fields = fields
        self.kind = fields[1]
        self.uptime = uptime
        self.unix = unix
    }

    func number(_ index: Int) -> Double? {
        guard let num = Double(fields[index]), num.isFinite else { return nil }
        return num
    }

    func motion(at time: Double) throws -> RecordedMotion {
        guard let accel = vector(6), let gyro = vector(9), let gravity = vector(12),
              (0.85...1.15).contains(simd_length(gravity)) else { throw CaptureReplayError.invalidFile }
        let up = simd_normalize(-gravity)
        let yaw = simd_dot(up, gyro)
        guard simd_length(accel).isFinite, yaw.isFinite else { throw CaptureReplayError.invalidFile }
        return RecordedMotion(time: time, up: up, acceleration: accel, yawRate: yaw)
    }

    func fix(at time: Double, point: ENPoint) -> RecordedFix? {
        guard let epoch = number(3), let accuracy = number(17), let speed = number(18),
              let bearing = number(20) else { return nil }
        return RecordedFix(arrival: time, measured: time - (unix - epoch), point: point, speed: speed,
                           bearing: bearing * .pi / 180, accuracy: accuracy)
    }

    private func vector(_ index: Int) -> SIMD3<Double>? {
        guard let x = number(index), let y = number(index + 1), let z = number(index + 2) else { return nil }
        return SIMD3(x, y, z)
    }
}
