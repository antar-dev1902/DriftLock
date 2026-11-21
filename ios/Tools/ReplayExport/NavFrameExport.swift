import DriftCore
import Foundation

/// Inverts the local WGS84 projection used to prepare the public replay pack.
struct ReplayProjection {
    let latitude: Double
    let longitude: Double

    init?(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude,
              latitude > -90, latitude < 90,
              (-180...180).contains(longitude) else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    func position(_ point: ENPoint) -> [String: Any] {
        let phi = latitude * .pi / 180
        let a = 6_378_137.0, eccentricitySquared = 6.69437999014e-3
        let sine = sin(phi)
        let w = sqrt(1 - eccentricitySquared * sine * sine)
        let northMetersPerRadian = a * (1 - eccentricitySquared) / (w * w * w)
        let eastMetersPerRadian = a / w * cos(phi)
        return [
            "lat_deg": latitude + point.north / northMetersPerRadian * 180 / .pi,
            "lon_deg": longitude + point.east / eastMetersPerRadian * 180 / .pi,
        ]
    }
}

func exportNavFrames(drive: RecordedDrive, trial: OutageTrial, projection: ReplayProjection) throws -> Data {
    let replay = try OutageReplay(trial: trial, motion: drive.motion, fixes: drive.fixes)
    // Include the exact transition milliseconds alongside the one-second samples.
    // Round arrival times up so a recorded fix cannot appear before it was available.
    let startMs = Int((trial.start * 1000).rounded(.up))
    let endMs = Int((trial.end * 1000).rounded(.down))
    var times = Set(stride(from: startMs, through: endMs, by: 1_000))
    for boundary in [trial.cut, trial.restore, replay.resumesAt].compactMap({ $0 }) {
        let milliseconds = Int((boundary * 1000).rounded(.up))
        if milliseconds <= endMs { times.insert(milliseconds) }
    }

    let missingPosition: [String: Any] = ["lat_deg": NSNull(), "lon_deg": NSNull()]
    var output = Data()
    for milliseconds in times.sorted() {
        let time = Double(milliseconds) / 1000
        let state: String
        let point: ENPoint?
        let speed: Double?
        let bearing: Double?
        if time < trial.cut || replay.resumesAt.map({ time >= $0 }) == true {
            guard let fix = replay.lastAdmittedFix(at: time) else { continue }
            state = "locked"
            point = fix.point
            speed = fix.speed
            bearing = fix.bearing
        } else {
            let pose = replay.coastPose(at: time)
            state = time < trial.restore ? "blackout" : "reacquiring"
            point = pose?.point
            speed = pose?.speed
            bearing = pose?.bearing
        }

        let record: [String: Any] = [
            "schema": "driftlock.nav.v1",
            "session_id": "swift-replay-\(trial.id)",
            "t_ms": milliseconds,
            "source": "recorded",
            "outage_state": state,
            "predicted": point.map(projection.position) ?? missingPosition,
            "motion": ["speed_mps": jsonNumber(speed), "heading_deg": jsonNumber(bearing.map(headingDegrees))],
            "uncertainty": ["radius_95_m": NSNull(), "calibrated": false],
            "road_match": ["status": "unavailable", "lat_deg": NSNull(), "lon_deg": NSNull()],
            "versions": ["engine": OutageReplay.config.estimator, "ml_model": NSNull()],
        ]
        output.append(try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]))
        output.append(10)
    }
    return output
}

private func headingDegrees(_ bearing: Double) -> Double {
    let period = 2 * Double.pi
    let wrapped = bearing.truncatingRemainder(dividingBy: period)
    let degrees = (wrapped < 0 ? wrapped + period : wrapped) * 180 / .pi
    return degrees < 360 ? degrees : 0
}

private func jsonNumber(_ number: Double?) -> Any {
    if let number { return number }
    return NSNull()
}
