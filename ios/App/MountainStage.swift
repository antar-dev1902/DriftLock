#if os(macOS)
import SwiftUI
import QuartzCore

enum MountainRoute: String, CaseIterable, Identifiable {
    case ridge = "Ridge road"
    case valley = "Valley road"
    var id: Self { self }
    var detail: String { self == .ridge ? "Higher pass · saved offline" : "Lower switchbacks · saved offline" }
}

enum MountainBeat: Int, CaseIterable, Identifiable {
    case lock, outage, closure, bypass, recovery
    var id: Self { self }
    static let duration = 55.0
    var time: Double { [0, 10, 24, 24, 49][rawValue] }
    var label: String { ["Calibrate", "Signal loss", "Road closed", "Detour", "Recovery"][rawValue] }
    var title: String {
        ["The road beyond GPS.", "The signal ends.\nThe drive continues.", "The planned road\nis closed.",
         "An offline way\nthrough.", "The sky opens\nagain."][rawValue]
    }
    var copy: String {
        [
            "A hill-station drive begins with GPS. While the signal is available, it anchors position and helps align the phone’s motion with the vehicle.",
            "In the mountain shadow, the last GPS fix anchors dead reckoning. The phone’s motion sensors help estimate progress. Uncertainty grows with time.",
            "A landslide blocks the main road. The driver stops and manually selects a route already saved on the device.",
            "The driver follows the saved detour. The motion estimate keeps updating through the turns while GPS is unavailable.",
            "Fresh GPS fixes are available again. DriftLock can compare them with the estimate and re-anchor when the fixes are accepted."
        ][rawValue]
    }
}

@MainActor
private final class MountainTimeline: ObservableObject {
    @Published var playback = MountainPlayback()
    @Published var elapsed = 0.0
}

struct MountainPresentation: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var timeline = MountainTimeline()
    private var playback: MountainPlayback {
        get { timeline.playback }
        nonmutating set { timeline.playback = newValue }
    }
    private var elapsed: Double {
        get { timeline.elapsed }
        nonmutating set { timeline.elapsed = newValue }
    }
    let showNavigationPreview: () -> Void

    private let clock = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private var playing: Bool { playback.startedAt != nil }
    private var blocked: Bool { elapsed >= MountainBeat.closure.time && playback.route == nil }
    private var beat: MountainBeat {
        if blocked { return .closure }
        return MountainBeat.allCases.last { $0.time <= elapsed } ?? .lock
    }
    private var state: String {
        if beat == .lock { return "GPS available" }
        if beat == .recovery { return "GPS restored" }
        return blocked ? "Stopped · GPS unavailable" : "Estimating from motion"
    }

    var body: some View {
        ZStack {
            AlpineLight(inShadow: beat != .lock && beat != .recovery)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
            HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("HIMALAYAN FOOTHILLS   /   SIMULATION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.25)
                        .foregroundStyle(DriftStyle.muted)
                    Text(beat.title)
                        .font(.system(size: 46, weight: .medium, design: .serif)).tracking(-2.3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(beat.copy)
                        .font(.system(size: 15)).lineSpacing(5).foregroundStyle(DriftStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Rectangle().fill(DriftStyle.border).frame(height: 1)
                    if blocked {
                        Text("Choose a saved detour").font(.headline)
                        ForEach(MountainRoute.allCases) { option in
                            Button {
                                let now = CACurrentMediaTime()
                                playback = MountainPlayback(elapsed: elapsed, startedAt: now, route: option)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Label("Reroute via " + option.rawValue.lowercased(), systemImage: "arrow.turn.up.right")
                                        .font(.subheadline.weight(.semibold))
                                    Text(option.detail).font(.caption).foregroundStyle(DriftStyle.muted)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.alpineButton()
                        }
                    } else if beat == .recovery {
                        Button(action: showNavigationPreview) {
                            Label("Open Navigation Preview", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                        }.alpineButton(primary: true)
                    } else {
                        if beat == .bypass, let route = playback.route {
                            Label(route.rawValue, systemImage: "arrow.turn.up.right")
                                .font(.subheadline.weight(.semibold))
                        }
                        Label(beat == .lock ? "Offline routes loaded" : "Position uncertainty growing",
                              systemImage: beat == .lock ? "square.and.arrow.down" : "location.slash")
                            .font(.subheadline.weight(.medium))
                    }
                    Text("Illustrative terrain and vehicle motion. Measured results are in the Test Lab.")
                        .font(.caption).foregroundStyle(DriftStyle.muted)
                }
                .padding(23)
                .frame(maxWidth: .infinity, alignment: .leading)

            }
            .frame(width: 290)
            .background(DriftStyle.background)
            Divider()
            ZStack(alignment: .topLeading) {
                MountainMap(playback: playback, reducedMotion: reduceMotion)
                    .equatable()
                    .accessibilityLabel("Three-dimensional terrain and vehicle route")
                HStack {
                    Label(state, systemImage: beat == .lock || beat == .recovery ? "location.fill" : "location.slash")
                        .font(.caption.weight(.semibold)).padding(.vertical, 9).padding(.horizontal, 13)
                        .driftGlass()
                    Spacer()
                    if elapsed >= 10 && elapsed < 49 {
                        Text(String(format: "GPS OUT  %02d s", Int(elapsed - 10)))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .padding(10).driftGlass()
                    }
                }.padding(18)
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Label("Active route", systemImage: "line.diagonal").foregroundStyle(Color(red: 0.03, green: 0.31, blue: 0.53))
                        Label("Saved detours", systemImage: "arrow.triangle.branch")
                        if blocked { Label("Closure", systemImage: "exclamationmark.triangle").foregroundStyle(DriftStyle.amber) }
                    }
                    .font(.caption.weight(.medium)).padding(10).driftGlass()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }.padding(18).allowsHitTesting(false)
            }
        }
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        togglePlayback()
                    } label: {
                        Label(playing ? "Pause" : "Play", systemImage: playing ? "pause.fill" : "play.fill")
                    }.alpineButton(primary: true).disabled(blocked)
                    Button("Restart", action: reset).alpineButton()
                    Slider(value: Binding(get: { elapsed }, set: seek), in: 0...MountainBeat.duration)
                        .accessibilityLabel("Presentation timeline")
                    Text(String(format: "0:%02d / 0:55", Int(elapsed)))
                        .font(.system(size: 11, design: .monospaced)).monospacedDigit()
                }
                HStack(spacing: 4) {
                    ForEach(MountainBeat.allCases) { chapter in
                        Button(chapter.label) { seekChapter(chapter) }
                            .disabled(playback.route == nil && (chapter == .bypass || chapter == .recovery))
                            .buttonStyle(.plain)
                            .font(.caption.weight(chapter == beat ? .bold : .medium))
                            .foregroundStyle(chapter == beat ? DriftStyle.mint : DriftStyle.muted)
                            .frame(maxWidth: .infinity)
                            .accessibilityAddTraits(chapter == beat ? [.isSelected] : [])
                    }
                }
            }.padding(.horizontal, 20).padding(.vertical, 12).background(DriftStyle.background)
                .overlay(alignment: .top) { Divider() }
            }
        }
        .onReceive(clock) { _ in
            guard playing else { return }
            elapsed = playback.time(at: CACurrentMediaTime())
            if elapsed >= playback.limit { seek(elapsed) }
        }
    }

    private func togglePlayback() {
        let now = CACurrentMediaTime()
        if playing {
            seek(playback.time(at: now))
        } else {
            if elapsed >= MountainBeat.duration { reset() }
            playback.startedAt = now
        }
    }

    private func seekChapter(_ chapter: MountainBeat) {
        if chapter == .closure { playback.route = nil }
        seek(chapter.time)
    }

    private func seek(_ time: Double) {
        elapsed = min(time, playback.limit)
        playback.elapsed = elapsed
        playback.startedAt = nil
    }

    private func reset() {
        elapsed = 0
        playback = MountainPlayback()
    }
}

private struct AlpineLight: View {
    let inShadow: Bool

    var body: some View {
        LinearGradient(colors: [Color(red: 0.76, green: 0.83, blue: 0.88),
                                Color(red: 0.94, green: 0.94, blue: 0.90),
                                inShadow ? Color(red: 0.76, green: 0.82, blue: 0.88) :
                                    Color(red: 0.97, green: 0.89, blue: 0.77)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .allowsHitTesting(false)
    }
}

extension View {
    @ViewBuilder fileprivate func alpineButton(primary: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if primary {
                self.buttonStyle(.glassProminent).tint(DriftStyle.mint).controlSize(.large)
            } else {
                self.buttonStyle(.glass).controlSize(.large)
            }
        } else {
            self.buttonStyle(DriftActionStyle(primary: primary))
        }
    }

    @ViewBuilder func driftGlass(radius: CGFloat = 17) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}
#endif

#if os(macOS)
struct DriftTestLab: View {
    let drive: RecordedDrive?
    let openReplay: () -> Void

    private var groups: [Group] {
        guard let drive, let data = try? HackathonReplay().benchmark(for: drive),
              let report = try? JSONDecoder().decode(Report.self, from: data) else { return [] }
        return report.groups
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                Text("Test Lab").font(.system(size: 44, weight: .bold)).tracking(-2.4)
                Text("Recorded Austin drive · GPS withheld for scoring")
                    .font(.subheadline).foregroundStyle(DriftStyle.muted)
                if groups.isEmpty {
                    Text("Recorded benchmark is unavailable.").driftPanel()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mean position error").font(.title3.bold())
                        Grid(alignment: .leading, horizontalSpacing: 25, verticalSpacing: 12) {
                            GridRow {
                                Text("Outage")
                                Text("Windows")
                                Text("DriftLock")
                                Text("Constant speed")
                                Text("Last position")
                            }.font(.caption.weight(.semibold)).foregroundStyle(DriftStyle.muted)
                            ForEach(groups, id: \.summary.outage_seconds) { group in
                                GridRow {
                                    Text("\(group.summary.outage_seconds) s").bold()
                                    Text("\(group.windows.filter { $0.failure == nil }.count) / \(group.windows.count)")
                                    ForEach(group.summary.methods, id: \.name) { method in
                                        Text(method.mean_error_m.map { String(format: "%.1f m", $0) } ?? "—")
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        Text("These are outage windows from one recorded drive. DriftLock beat constant speed in two of five 30-second windows. Last position was better in the one scored 90-second window.")
                            .font(.caption).foregroundStyle(DriftStyle.muted)
                        Button("Inspect replay windows", action: openReplay).alpineButton(primary: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).driftPanel()
                }
                VStack(alignment: .leading, spacing: 11) {
                    Text("From motion to navigation").font(.title3.bold())
                    Text("GPS anchor → motion and alignment → dead reckoning → fresh GPS")
                        .font(.system(.subheadline, design: .monospaced))
                    Text("The recorded benchmark exercises the Swift physics estimator. The mountain storyline illustrates how offline route choices could work in the product.")
                    Divider()
                    Text("Virtual odometer research").font(.headline)
                    Text("Six IMU channels feed a compact CNN + GRU. The intended output is vehicle-forward speed with uncertainty. The existing exploratory checkpoint learned recorded reference values whose physical meaning remains unresolved.")
                    Text("To validate it, collect independent drives with time-aligned signed speed and reviewed sensor axes, then compare physics-only and ML-assisted replay on held-out outages.")
                    Text("Exploratory validation MAE 3.86 in recorded units. Holding the pre-outage value beat the model in the cut-window comparison.")
                    Text("Exploratory checkpoint · Disabled for navigation").font(.caption.bold())
                        .foregroundStyle(DriftStyle.amber)
                }
                .frame(maxWidth: .infinity, alignment: .leading).driftPanel()
            }.padding(28).frame(maxWidth: 920).frame(maxWidth: .infinity)
        }
    }

    private struct Report: Decodable { let groups: [Group] }
    private struct Group: Decodable { let summary: Summary; let windows: [Window] }
    private struct Summary: Decodable { let outage_seconds: Int; let methods: [Method] }
    private struct Method: Decodable { let name: String; let mean_error_m: Double? }
    private struct Window: Decodable { let failure: String? }
}
#endif
