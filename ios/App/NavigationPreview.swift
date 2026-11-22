#if os(macOS)
import SwiftUI
import QuartzCore
import simd

struct NavigationPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var drive = PreviewDrive()
    let openTestLab: () -> Void

    private let clock = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !drive.playing)) { _ in
                let now = CACurrentMediaTime()
                let pose = MountainDrive.pose(at: drive.playback.time(at: now), route: drive.playback.route)
                let projection = drive.projection(in: size, pose: pose, now: now, reduceMotion: reduceMotion)
                NavigationMap(projection: projection, pose: pose, selected: drive.playback.route,
                              blocked: drive.roadClosed, estimated: drive.estimated)
                    .gesture(DragGesture(minimumDistance: 5)
                        .onChanged { drive.drag($0.translation, startingFrom: projection) }
                        .onEnded { _ in drive.endDrag() })
            }
            .clipped()
            .overlay(alignment: .topLeading) { maneuver.padding(20) }
            .overlay(alignment: .topTrailing) { mapStatus.padding(20) }
            .overlay(alignment: .bottomLeading) { tripControls.padding(20) }
            .overlay(alignment: .bottomTrailing) { mapControls(size: size).padding(20) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Navigation Preview")
        }
        .onReceive(clock) { _ in drive.tick() }
    }

    private var maneuver: some View {
        HStack(spacing: 15) {
            Image(systemName: drive.maneuverIcon)
                .font(.system(size: 29, weight: .semibold))
                .frame(width: 40, height: 45)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(drive.maneuverTitle).font(.system(size: 23, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text(drive.maneuverDetail).font(.subheadline).foregroundStyle(.white.opacity(0.84))
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(width: 328, alignment: .leading)
        .foregroundStyle(.white)
        .background(drive.waitingForRoute ? MapStyle.warning : MapStyle.guidance, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: MapStyle.ink.opacity(0.15), radius: 14, y: 6)
    }

    private var mapStatus: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: drive.estimated ? "location.slash" : "location.fill")
                    .foregroundStyle(drive.estimated ? MapStyle.warning : MapStyle.guidance)
                Text(drive.signalTitle).fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.white, in: Capsule())
            .shadow(color: MapStyle.ink.opacity(0.09), radius: 9, y: 3)
            Label("Offline map · Simulation", systemImage: "arrow.down.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(MapStyle.ink)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(.white.opacity(0.91), in: Capsule())
        }
    }

    private var tripControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            if drive.waitingForRoute {
                Text("Choose a saved detour").font(.headline)
                ForEach(MountainRoute.allCases) { route in
                    Button {
                        drive.select(route)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(route.rawValue).font(.subheadline.weight(.semibold))
                                Text(route == .ridge ? "Higher pass" : "Lower switchbacks")
                                    .font(.caption).foregroundStyle(MapStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "arrow.turn.up.right").foregroundStyle(MapStyle.route)
                        }
                        .padding(9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(MapStyle.controls, in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHint("Continue from the junction via this saved route")
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered").font(.title3.weight(.semibold)).foregroundStyle(MapStyle.guidance)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pinecrest Pass").font(.headline)
                        Text(drive.tripDetail).font(.caption.weight(.medium)).foregroundStyle(MapStyle.muted)
                    }
                    Spacer(minLength: 5)
                }
                ProgressView(value: drive.elapsed, total: MountainBeat.duration)
                    .tint(MapStyle.route)
                    .accessibilityLabel("Simulation progress")
                HStack {
                    if drive.arrived {
                        Button("Open Test Lab", action: openTestLab).buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            drive.togglePlayback(reduceMotion: reduceMotion)
                        } label: {
                            Label(drive.playing ? "Pause" : (drive.elapsed == 0 ? "Start drive" : "Resume"),
                                  systemImage: drive.playing ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if drive.elapsed > 0 || drive.playing { restartButton }
                }
            }
            if drive.waitingForRoute { restartButton }
        }
        .padding(15)
        .frame(width: 282, alignment: .leading)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .controlSize(.regular)
        .tint(MapStyle.route)
        .foregroundStyle(MapStyle.ink)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(MapStyle.ink.opacity(0.10)) }
        .shadow(color: MapStyle.ink.opacity(0.15), radius: 14, y: 5)
    }

    private var restartButton: some View {
        Button("Restart", systemImage: "arrow.counterclockwise", action: drive.reset)
            .buttonStyle(.bordered)
    }

    private func mapControls(size: CGSize) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(spacing: 2) {
                Image(systemName: "location.north.fill").font(.system(size: 12, weight: .semibold))
                Text("N").font(.system(size: 10, weight: .bold))
            }
            .frame(width: 38, height: 43)
            .foregroundStyle(MapStyle.muted)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("North is up")

            VStack(spacing: 0) {
                mapButton("Zoom in", icon: "plus") { drive.zoom(1.28, size: size, reduceMotion: reduceMotion) }
                Divider().frame(width: 26)
                mapButton("Zoom out", icon: "minus") { drive.zoom(1 / 1.28, size: size, reduceMotion: reduceMotion) }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 7) {
                mapButton("Show full route", icon: "map", action: drive.overview)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
                mapButton("Center on vehicle", icon: "location.fill") { drive.recenter() }
                    .foregroundStyle(MapStyle.route)
                    .background(.white, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .shadow(color: MapStyle.ink.opacity(0.13), radius: 8, y: 3)
    }

    private func mapButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}

@MainActor
private final class PreviewDrive: ObservableObject {
    @Published private(set) var playback = MountainPlayback()
    @Published private(set) var elapsed = 0.0
    @Published private var camera = Camera.overview
    private var dragStart: MapProjection?

    private enum Camera {
        case overview
        case following(since: CFTimeInterval)
        case manual(center: SIMD2<Float>, scale: CGFloat)
    }

    var playing: Bool { playback.startedAt != nil }
    var arrived: Bool { elapsed >= MountainBeat.duration }
    var roadClosed: Bool { elapsed >= MountainBeat.closure.time }
    var waitingForRoute: Bool { roadClosed && playback.route == nil }
    var estimated: Bool { elapsed >= MountainBeat.outage.time && elapsed < MountainBeat.recovery.time }

    var signalTitle: String {
        if estimated { return "GPS lost · Estimated position" }
        return elapsed >= MountainBeat.recovery.time ? "GPS restored" : "GPS available"
    }

    var maneuverTitle: String {
        if arrived { return "You’ve arrived" }
        if waitingForRoute { return "Landslide ahead" }
        if let route = playback.route { return "Follow \(route.rawValue.lowercased())" }
        return elapsed == 0 ? "Head to Pinecrest" : "Continue on Foothill Road"
    }

    var maneuverIcon: String {
        if arrived { return "flag.checkered" }
        if waitingForRoute { return "exclamationmark.triangle.fill" }
        if let route = playback.route { return route == .ridge ? "arrow.turn.up.left" : "arrow.turn.up.right" }
        return "arrow.up"
    }

    var maneuverDetail: String {
        if arrived { return "Pinecrest Pass" }
        if waitingForRoute { return "Main road closed" }
        if playback.route != nil { return "Saved offline detour" }
        return elapsed == 0 ? "Starting from Foothill Village" : "Toward Pinecrest Pass"
    }

    var tripDetail: String {
        if arrived { return "Drive complete" }
        let pose = MountainDrive.pose(at: elapsed, route: playback.route)
        let ahead = pose.road.length - pose.distance
        let remaining = elapsed < MountainBeat.closure.time ? ahead + MountainDrive.main.length : ahead
        return "\(MapStyle.distance(remaining)) remaining"
    }

    func togglePlayback(reduceMotion: Bool) {
        let now = CACurrentMediaTime()
        if playing {
            stop(at: playback.time(at: now))
        } else {
            if elapsed == 0 { camera = .following(since: reduceMotion ? now - 2 : now) }
            playback.startedAt = now
        }
    }

    func tick() {
        guard playing else { return }
        let time = playback.time(at: CACurrentMediaTime())
        if time >= playback.limit {
            stop(at: time)
            if waitingForRoute { overview() }
        } else {
            elapsed = time
        }
    }

    func select(_ route: MountainRoute) {
        guard waitingForRoute else { return }
        let now = CACurrentMediaTime()
        playback = MountainPlayback(elapsed: MountainBeat.closure.time, startedAt: now, route: route)
        camera = .following(since: now)
    }

    func reset() {
        stop(at: 0)
        playback = MountainPlayback()
        overview()
    }

    func overview() { camera = .overview }

    func recenter() { camera = .following(since: CACurrentMediaTime() - 2) }

    func zoom(_ factor: CGFloat, size: CGSize, reduceMotion: Bool) {
        let now = CACurrentMediaTime()
        let pose = MountainDrive.pose(at: playback.time(at: now), route: playback.route)
        let current = projection(in: size, pose: pose, now: now, reduceMotion: reduceMotion)
        camera = .manual(center: current.center, scale: min(max(current.scale * factor, 3), 29))
    }

    func drag(_ translation: CGSize, startingFrom projection: MapProjection) {
        if dragStart == nil { dragStart = projection }
        guard let origin = dragStart else { return }
        let delta = SIMD2(Float(translation.width / origin.scale), Float(translation.height / origin.scale))
        let center = simd_clamp(origin.center - delta, SIMD2(-73, -52), SIMD2(73, 52))
        camera = .manual(center: center, scale: origin.scale)
    }

    func endDrag() { dragStart = nil }

    func projection(in size: CGSize, pose: MountainDrive.Pose, now: CFTimeInterval,
                    reduceMotion: Bool) -> MapProjection {
        let fit = max(3, min((size.width - 96) / 112, (size.height - 90) / 57))
        let overviewCenter = SIMD2<Float>(-0.5, -2.0)
        switch camera {
        case .overview:
            return MapProjection(size: size, center: overviewCenter, scale: fit)
        case let .manual(center, scale):
            return MapProjection(size: size, center: center, scale: scale)
        case let .following(start):
            let amount = reduceMotion ? 1 : mountainEase(Float((now - start) / 1.8))
            let scale = fit + (fit * 1.65 - fit) * CGFloat(amount)
            let ahead = pose.road.position(at: pose.distance + 5.5)
            let followCenter = SIMD2(ahead.x, ahead.z)
            let center = overviewCenter + (followCenter - overviewCenter) * amount
            return MapProjection(size: size, center: center, scale: scale)
        }
    }

    private func stop(at time: Double) {
        playback.elapsed = time
        playback.startedAt = nil
        elapsed = time
    }
}

#endif
