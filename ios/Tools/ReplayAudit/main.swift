import DriftCore
import Foundation

struct Report: Encodable {
    let contract: String
    let dataset: URL?
    let config: ReplayConfig
    let measuredWindows: Int
    let independentDrives: Int
    let meanOfWindowMeanDriftlockErrorMeters: Double
    let meanOfWindowMeanBaselineErrorMeters: Double
    let windowsWithLowerMeanError: Int
    let trials: [TrialMetrics]
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: driftlock-replay-audit DRIVE.json\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let drive = try input.pathExtension.lowercased() == "csv"
    ? RecordedDrive.loadCapture(from: input) : RecordedDrive.load(from: input)
let trials = try drive.trials.map { try OutageReplay(trial: $0, motion: drive.motion, fixes: drive.fixes).metrics }
let measured = trials.filter { $0.meanDriftlockErrorMeters != nil && $0.meanBaselineErrorMeters != nil }
guard !measured.isEmpty else {
    FileHandle.standardError.write(Data("No complete outage comparisons.\n".utf8))
    exit(1)
}
let report = Report(
    contract: drive.contract, dataset: drive.sourceURL, config: OutageReplay.config,
    measuredWindows: measured.count, independentDrives: 1,
    meanOfWindowMeanDriftlockErrorMeters: measured.compactMap(\.meanDriftlockErrorMeters).reduce(0, +) / Double(measured.count),
    meanOfWindowMeanBaselineErrorMeters: measured.compactMap(\.meanBaselineErrorMeters).reduce(0, +) / Double(measured.count),
    windowsWithLowerMeanError: measured.count { trial in
        (trial.meanDriftlockErrorMeters ?? .infinity) < (trial.meanBaselineErrorMeters ?? 0)
    },
    trials: trials
)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
let json = try encoder.encode(report)
FileHandle.standardOutput.write(json)
FileHandle.standardOutput.write(Data("\n".utf8))
