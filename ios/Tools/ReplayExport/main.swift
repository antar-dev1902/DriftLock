import DriftCore
import Foundation

struct PlaybackPack: Encodable {
    let schema = "driftlock-flutter-playback-v1"
    let title: String
    let device: String
    let windows: [Window]
}

struct Window: Encodable {
    let id: String
    let cut: Double
    let restore: Double
    let resumes: Double?
    let duration: Double
    let observed: [[Double]]
    let withheld: [[Double]]
    let estimate: [[Double]]
    let baseline: [[Double]]
    let metrics: TrialMetrics
}

let arguments = CommandLine.arguments

func usage() -> Never {
    FileHandle.standardError.write(Data("""
    Usage: driftlock-export-playback DRIVE.json
           driftlock-export-playback --hackathon-playback|--hackathon-benchmark DRIVE.json|CAPTURE.csv
           driftlock-export-playback --nav-frames DRIVE.json WINDOW_ID ORIGIN_LAT ORIGIN_LON

    """.utf8))
    exit(2)
}

if arguments.count == 6, arguments[1] == "--nav-frames" {
    guard let projection = ReplayProjection(latitude: Double(arguments[4]), longitude: Double(arguments[5])) else {
        usage()
    }
    let drive = try RecordedDrive.load(from: URL(fileURLWithPath: arguments[2]))
    guard let trial = drive.trials.first(where: { $0.id == arguments[3] }) else {
        FileHandle.standardError.write(Data("The requested window is not in the replay pack.\n".utf8))
        exit(2)
    }
    FileHandle.standardOutput.write(try exportNavFrames(drive: drive, trial: trial, projection: projection))
    exit(0)
}

if arguments.count == 3, ["--hackathon-playback", "--hackathon-benchmark"].contains(arguments[1]) {
    let url = URL(fileURLWithPath: arguments[2])
    let drive = try url.pathExtension.lowercased() == "csv"
        ? RecordedDrive.loadCapture(from: url) : RecordedDrive.load(from: url)
    let exporter = HackathonReplay()
    let data = try arguments[1] == "--hackathon-playback"
        ? exporter.playback(for: drive) : exporter.benchmark(for: drive)
    FileHandle.standardOutput.write(data)
    exit(0)
}

guard arguments.count == 2, arguments[1] != "--nav-frames" else { usage() }
let drive = try RecordedDrive.load(from: URL(fileURLWithPath: arguments[1]))
let windows = try drive.trials.map { trial in
    let replay = try OutageReplay(trial: trial, motion: drive.motion, fixes: drive.fixes)
    let timeline = stride(from: trial.cut, through: replay.resumesAt ?? trial.restore, by: 0.2)
    func sample(_ point: ENPoint, at time: Double) -> [Double] {
        [time - trial.start, point.east, point.north].map { ($0 * 10000).rounded() / 10000 }
    }
    let observed = replay.fixes.filter {
        $0.arrival < trial.cut || ($0.arrival >= trial.restore && $0.measured >= trial.restore)
    }
    return Window(
        id: trial.id, cut: trial.cut - trial.start, restore: trial.restore - trial.start,
        resumes: replay.resumesAt.map { $0 - trial.start }, duration: trial.end - trial.start,
        observed: observed.map { sample($0.point, at: $0.arrival) },
        withheld: replay.hiddenFixes.map { sample($0.point, at: $0.arrival) },
        estimate: timeline.compactMap { t in replay.coastPose(at: t).map { sample($0.point, at: t) } },
        baseline: timeline.compactMap { t in replay.baselinePose(at: t).map { sample($0.point, at: t) } },
        metrics: replay.metrics
    )
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
let json = try encoder.encode(PlaybackPack(title: drive.title, device: drive.device, windows: windows))
FileHandle.standardOutput.write(json)
FileHandle.standardOutput.write(Data("\n".utf8))
