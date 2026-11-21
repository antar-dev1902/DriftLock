import Foundation
import simd

public struct ENPoint: Equatable, Sendable {
    public let east: Double
    public let north: Double

    public init(east: Double, north: Double) {
        self.east = east
        self.north = north
    }

    public func distance(to other: Self) -> Double {
        hypot(other.east - east, other.north - north)
    }

    func advanced(meters: Double, bearing: Double) -> Self {
        Self(east: east + meters * sin(bearing), north: north + meters * cos(bearing))
    }
}

public struct RecordedMotion: Decodable, Sendable {
    public let time: Double
    public let up: SIMD3<Double>
    public let acceleration: SIMD3<Double>
    public let yawRate: Double

    public init(time: Double, up: SIMD3<Double>, acceleration: SIMD3<Double>, yawRate: Double) {
        self.time = time
        self.up = up
        self.acceleration = acceleration
        self.yawRate = yawRate
    }

    public init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        guard values.count == 8 else { throw ReplayError.invalidRecording }
        time = try values.decode(Double.self)
        up = try Self.vector(&values)
        acceleration = try Self.vector(&values)
        yawRate = try values.decode(Double.self)
    }

    private static func vector(_ values: inout any UnkeyedDecodingContainer) throws -> SIMD3<Double> {
        try SIMD3(values.decode(Double.self), values.decode(Double.self), values.decode(Double.self))
    }
}

public struct RecordedFix: Decodable, Sendable {
    public let arrival: Double
    public let measured: Double
    public let point: ENPoint
    public let speed: Double
    public let bearing: Double
    public let accuracy: Double

    public init(arrival: Double, measured: Double, point: ENPoint, speed: Double, bearing: Double, accuracy: Double) {
        self.arrival = arrival
        self.measured = measured
        self.point = point
        self.speed = speed
        self.bearing = bearing
        self.accuracy = accuracy
    }

    public init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        guard values.count == 7 else { throw ReplayError.invalidRecording }
        arrival = try values.decode(Double.self)
        measured = try values.decode(Double.self)
        point = try ENPoint(east: values.decode(Double.self), north: values.decode(Double.self))
        speed = try values.decode(Double.self)
        bearing = try values.decode(Double.self)
        accuracy = try values.decode(Double.self)
    }

    var usable: Bool {
        [arrival, measured, point.east, point.north, speed, bearing, accuracy].allSatisfy(\.isFinite)
            && measured <= arrival && arrival - measured <= 1.5 && (0...65).contains(speed)
            && bearing >= 0 && bearing < .pi * 2 && accuracy > 0 && accuracy <= 20
    }
}

public struct OutageTrial: Decodable, Identifiable, Sendable {
    public let id: String
    public let start: Double
    public let cut: Double
    public let restore: Double
    public let end: Double

    public init(id: String, start: Double, cut: Double, restore: Double, end: Double) {
        self.id = id
        self.start = start
        self.cut = cut
        self.restore = restore
        self.end = end
    }

    public var duration: Double { restore - cut }
}

public enum ReplayError: LocalizedError {
    case invalidRecording, missingAnchor

    public var errorDescription: String? {
        switch self {
        case .invalidRecording: "This route pack has an invalid format or clock."
        case .missingAnchor: "This window has no recent moving location fix before the outage."
        }
    }
}

public struct RecordedDrive: Decodable, Sendable {
    public let contract: String
    public let title: String
    public let place: String
    public let device: String
    public let recordedOn: String
    public let sourceURL: URL?
    public let motion: [RecordedMotion]
    public let fixes: [RecordedFix]
    public let trials: [OutageTrial]

    public static func load(from url: URL) throws -> Self {
        let drive = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        guard drive.contract == "driftlock-ios-replay-v1",
              drive.sourceURL?.scheme == "https",
              let lastMotion = drive.motion.last,
              !drive.fixes.isEmpty, !drive.trials.isEmpty,
              Set(drive.trials.map(\.id)).count == drive.trials.count,
              drive.motion.allSatisfy({ sample in
                  sample.time.isFinite && sample.time >= 0 && sample.yawRate.isFinite
                      && (0.99...1.01).contains(simd_length(sample.up))
                      && simd_length(sample.acceleration).isFinite
              }),
              drive.fixes.allSatisfy(\.usable),
              increases(drive.motion.map(\.time)),
              increases(drive.fixes.map(\.arrival)),
              increases(drive.fixes.map(\.measured)),
              drive.trials.allSatisfy({ trial in
                  trial.start >= 0 && trial.cut > trial.start && trial.restore > trial.cut
                      && trial.end > trial.restore && trial.end <= lastMotion.time
              })
        else { throw ReplayError.invalidRecording }
        return drive
    }

    private static func increases(_ values: [Double]) -> Bool {
        zip(values, values.dropFirst()).allSatisfy { $0.0 < $0.1 }
    }
}
