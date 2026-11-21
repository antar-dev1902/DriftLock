import Charts
import SwiftUI

struct ReplayWindow: Identifiable {
    let trial: OutageTrial
    let replay: OutageReplay?

    var id: String { trial.id }
}

@MainActor
private final class ReplayPlayback: ObservableObject {
    @Published var windowIndex = 0
    @Published var time: Double
    @Published var playing = false
    @Published var rate: Double = 2
    @Published var showReference = true

    init(start: Double) { time = start }
}

struct ReplayScreen: View {
    let drive: RecordedDrive
    let openEvidence: () -> Void
    @StateObject private var playback: ReplayPlayback
    @Environment(\.scenePhase) private var scenePhase

    private let windows: [ReplayWindow]

    init(drive: RecordedDrive, openEvidence: @escaping () -> Void) {
        self.drive = drive
        self.openEvidence = openEvidence
        windows = drive.trials.map { trial in
            ReplayWindow(trial: trial, replay: try? OutageReplay(trial: trial, motion: drive.motion, fixes: drive.fixes))
        }
        _playback = StateObject(wrappedValue: ReplayPlayback(start: drive.trials[0].start))
    }

    private var time: Double { playback.time }
    private var window: ReplayWindow { windows[playback.windowIndex] }
    private var trial: OutageTrial { window.trial }
    private var phase: ReplayPhase { window.replay?.phase(at: time) ?? .unavailable }
    private var elapsed: Double { time - trial.start }
    private var outageElapsed: Double { min(max(time - trial.cut, 0), trial.duration) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                title
                if let replay = window.replay {
                    trajectory(replay)
                    controls
                    results(replay)
                } else {
                    ContentUnavailableView("Window unavailable", systemImage: "location.slash",
                                           description: Text(ReplayError.missingAnchor.errorDescription ?? ""))
                        .driftPanel()
                }
                Button(action: openEvidence) {
                    Label("View benchmark", systemImage: "chart.xyaxis.line")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DriftStyle.mint)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .task(id: playback.playing) { if playback.playing { await play() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { playback.playing = false }
        }
    }

    private var title: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titleText
                Spacer(minLength: 0)
                windowPicker
            }
            VStack(alignment: .leading, spacing: 8) {
                titleText
                windowPicker
            }
        }
    }

    private var titleText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(drive.title).font(.system(size: 31, weight: .bold)).tracking(-1.0)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: true, vertical: false)
            Text("\(drive.device) recording  ·  \(drive.recordedOn)")
                .font(.caption).foregroundStyle(DriftStyle.muted)
        }
    }

    private var windowPicker: some View {
        Menu {
            ForEach(Array(windows.enumerated()), id: \.element.id) { index, candidate in
                Button {
                    playback.playing = false
                    playback.windowIndex = index
                    playback.time = candidate.trial.start
                } label: {
                    if index == playback.windowIndex {
                        Label("Window \(candidate.id)", systemImage: "checkmark")
                    } else {
                        Text("Window \(candidate.id)")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(window.id) / \(windows.count)").monospacedDigit()
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(DriftStyle.panel, in: RoundedRectangle(cornerRadius: 9))
        }
        .accessibilityLabel("Outage window \(window.id) of \(windows.count)")
    }

    private func trajectory(_ replay: OutageReplay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoutePlot(replay: replay, time: time, showReference: playback.showReference)
                .frame(height: 286)
                .accessibilityLabel("Offline trajectory")
                .accessibilityValue(status.title)
                .overlay(alignment: .topLeading) {
                    statusBadge
                        .padding(12)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        playback.showReference.toggle()
                    } label: {
                        Image(systemName: playback.showReference ? "eye" : "eye.slash")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(DriftStyle.background.opacity(0.91), in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(DriftStyle.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(playback.showReference ? "Hide withheld GPS trace" : "Show withheld GPS trace")
                    .padding(9)
                }
            Divider().overlay(DriftStyle.border)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 13) { legendEntries }
                VStack(alignment: .leading, spacing: 9) { legendEntries }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
        }
        .background(DriftStyle.panel, in: RoundedRectangle(cornerRadius: 15))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(DriftStyle.border).allowsHitTesting(false) }
    }

    @ViewBuilder private var legendEntries: some View {
        legend("Driftlock", color: DriftStyle.mint)
        legend("Last speed + heading", color: DriftStyle.amber)
        legend("Withheld GPS", color: DriftStyle.muted.opacity(playback.showReference ? 1 : 0.48))
    }

    private func legend(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(DriftStyle.muted).fixedSize()
        }
    }

    private var status: (title: String, color: Color, icon: String) {
        switch phase {
        case .tracking: ("GPS available", DriftStyle.mint, "location.fill")
        case .coasting: ("GPS withheld", DriftStyle.amber, "location.slash.fill")
        case .unavailable: ("Motion unavailable", DriftStyle.amber, "exclamationmark.triangle.fill")
        case .recovered: ("GPS restored", DriftStyle.mint, "location.fill")
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: status.icon).foregroundStyle(status.color)
            Text(status.title).foregroundStyle(DriftStyle.ink)
            if phase == .coasting {
                Text(String(format: "%.1f s", outageElapsed)).foregroundStyle(status.color)
                    .monospacedDigit()
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DriftStyle.background.opacity(0.94), in: Capsule())
        .overlay { Capsule().strokeBorder(status.color.opacity(0.3)) }
    }

    private var controls: some View {
        VStack(spacing: 9) {
            Slider(value: $playback.time, in: trial.start...trial.end,
                   onEditingChanged: { editing in if editing { playback.playing = false } })
                .accessibilityLabel("Replay timeline")
                .accessibilityValue("\(Int(elapsed)) seconds")
            HStack {
                Text(clockLabel(elapsed))
                Spacer()
                Text("\(Int(trial.duration)) s GPS outage")
                Spacer()
                Text(clockLabel(trial.end - trial.start))
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(DriftStyle.muted)
            HStack(spacing: 8) {
                Button {
                    if time >= trial.end { playback.time = trial.start }
                    playback.playing.toggle()
                } label: {
                    Label(playback.playing ? "Pause" : "Play", systemImage: playback.playing ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DriftActionStyle(primary: true))
                if time < trial.cut {
                    Button {
                        playback.time = trial.cut
                        playback.playing = true
                    } label: {
                        Label("Start outage", systemImage: "location.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DriftActionStyle())
                } else {
                    Button {
                        playback.playing = false
                        playback.time = trial.start
                    } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DriftActionStyle())
                }
                Menu {
                    ForEach([1.0, 2.0, 4.0], id: \.self) { speed in
                        Button("\(Int(speed))×", action: { playback.rate = speed })
                    }
                } label: {
                    Text("\(Int(playback.rate))×").font(.subheadline.weight(.semibold)).monospacedDigit()
                        .frame(width: 43, height: 45)
                }
                .accessibilityLabel("Playback speed, \(Int(playback.rate)) times")
            }
        }
        .driftPanel()
    }

    private func results(_ replay: OutageReplay) -> some View {
        let metric = replay.metrics
        return VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Position error").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                if phase == .recovered {
                    Text("\(metric.samples) GPS fixes")
                        .font(.caption.monospacedDigit()).foregroundStyle(DriftStyle.muted)
                }
            }
            if phase == .recovered, let drift = metric.meanDriftlockErrorMeters, let baseline = metric.meanBaselineErrorMeters {
                HStack(spacing: 16) {
                    metricTile("Driftlock", value: drift, color: DriftStyle.mint)
                    metricTile("Last speed + heading", value: baseline, color: DriftStyle.amber)
                }
                Chart {
                    ForEach(Array(replay.errors.enumerated()), id: \.offset) { _, sample in
                        LineMark(x: .value("Outage seconds", sample.time - trial.cut),
                                 y: .value("Error in metres", sample.driftlock))
                            .foregroundStyle(by: .value("Estimate", "Driftlock"))
                        LineMark(x: .value("Outage seconds", sample.time - trial.cut),
                                 y: .value("Error in metres", sample.baseline))
                            .foregroundStyle(by: .value("Estimate", "Last speed + heading"))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartForegroundStyleScale(["Driftlock": DriftStyle.mint, "Last speed + heading": DriftStyle.amber])
                .chartLegend(.hidden)
                .chartXAxis { AxisMarks(values: [0.0, 10.0, 20.0, 30.0]) { AxisGridLine(); AxisValueLabel() } }
                .chartXScale(domain: 0...trial.duration)
                .chartYAxisLabel("metres")
                .frame(height: 112)
                .accessibilityLabel("Error against withheld GPS during the outage")
                Text("Mean error against withheld phone GPS. \(replay.usesAcceleration ? "Gyro + calibrated acceleration." : "Gyro with speed held from the last fix.")")
                    .font(.caption).foregroundStyle(DriftStyle.muted)
            } else {
                Text(phase == .recovered ? "This window has incomplete comparison data."
                     : "The comparison appears when GPS returns.")
                    .font(.subheadline)
                    .foregroundStyle(DriftStyle.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftPanel()
    }

    private func metricTile(_ name: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 27, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(name + " · m").font(.caption).foregroundStyle(DriftStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func clockLabel(_ value: Double) -> String {
        let seconds = Int(value)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @MainActor private func play() async {
        let clock = ContinuousClock()
        var previous = clock.now
        while !Task.isCancelled && playback.playing {
            do { try await clock.sleep(for: .milliseconds(33)) } catch { return }
            let now = clock.now
            let dt = previous.duration(to: now).components
            previous = now
            let tick = max(0, Double(dt.seconds) + Double(dt.attoseconds) / 1e18)
            playback.time = min(trial.end, time + tick * playback.rate)
            if time >= trial.end { playback.playing = false }
        }
    }
}

struct EvidenceSheet: View {
    let drive: RecordedDrive
    @Environment(\.dismiss) private var dismiss

    private var results: [TrialMetrics] {
        drive.trials.compactMap { trial in
            (try? OutageReplay(trial: trial, motion: drive.motion, fixes: drive.fixes))?.metrics
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introduction
                    comparisons
                    method
                    if let source = drive.sourceURL {
                        Link("Open cloudpose source dataset", destination: source)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DriftStyle.mint)
                    }
                }
                .padding(20)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .background(DriftStyle.background)
            .foregroundStyle(DriftStyle.ink)
            .navigationTitle("Replay evidence")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(drive.title).font(.title.bold()).accessibilityAddTraits(.isHeader)
            if drive.sourceURL != nil {
                Text("Recorded on a dash-mounted \(drive.device) in \(drive.place).")
            } else {
                Text("Recorded with Driftlock on your iPhone.")
            }
            Text("\(drive.trials.count) fixed 30-second GPS outage windows from one drive.")
        }
        .font(.subheadline)
        .foregroundStyle(DriftStyle.muted)
    }

    private var comparisons: some View {
        let metrics = results
        let pairs = metrics.compactMap { trial -> (drift: Double, baseline: Double)? in
            guard let drift = trial.meanDriftlockErrorMeters, let baseline = trial.meanBaselineErrorMeters else { return nil }
            return (drift, baseline)
        }
        return VStack(alignment: .leading, spacing: 9) {
            Text("Mean error vs withheld phone GPS (m)").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Window")
                    Text("Driftlock").foregroundStyle(DriftStyle.mint)
                    Text("Baseline").foregroundStyle(DriftStyle.amber)
                }.font(.caption.weight(.semibold))
                ForEach(drive.trials) { trial in
                    let metric = metrics.first { $0.id == trial.id }
                    GridRow {
                        Text(trial.id)
                        errorValue(metric?.meanDriftlockErrorMeters)
                        errorValue(metric?.meanBaselineErrorMeters)
                    }.font(.subheadline.monospacedDigit())
                }
                if !pairs.isEmpty {
                    let count = Double(pairs.count)
                    GridRow {
                        Text("Mean")
                        errorValue(pairs.reduce(0) { $0 + $1.drift } / count).foregroundStyle(DriftStyle.mint)
                        errorValue(pairs.reduce(0) { $0 + $1.baseline } / count).foregroundStyle(DriftStyle.amber)
                    }.font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Mean error comparison table")
            if !pairs.isEmpty {
                Text("Driftlock had lower error in \(pairs.filter { $0.drift < $0.baseline }.count) of \(pairs.count) scored windows.")
                    .font(.caption).foregroundStyle(DriftStyle.muted)
            }
            Text("Baseline holds the last measured speed and heading.")
                .font(.caption).foregroundStyle(DriftStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftPanel()
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("How the replay runs").font(.headline).foregroundStyle(DriftStyle.ink)
            Text("Both estimates start from the same GPS fix. At the cut, Driftlock follows the recorded gyroscope and uses acceleration when the lead-in can establish the mount direction. GPS stays hidden from both estimates until a fresh fix arrives after the outage.")
            Text("The reference is phone GPS. These windows show behaviour on one recorded drive. Survey-grade position and live iPhone navigation remain unverified.")
        }
        .font(.subheadline)
        .foregroundStyle(DriftStyle.muted)
    }

    private func errorValue(_ value: Double?) -> Text {
        value.map { Text($0, format: .number.precision(.fractionLength(1))) } ?? Text("—")
    }
}
