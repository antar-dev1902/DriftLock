import SwiftUI

struct RoutePlot: View {
    let replay: OutageReplay
    let time: Double
    let showReference: Bool

    private var trial: OutageTrial { replay.trial }

    var body: some View {
        Canvas { context, size in
            let extent = PlotExtent(points: replay.fixes.map(\.point)
                                    + [replay.baselinePose(at: trial.restore)?.point,
                                       replay.coastPose(at: trial.restore)?.point].compactMap { $0 }, size: size)
            drawGrid(in: context, size: size, extent: extent)
            let visibleFixes = replay.fixes.filter { $0.arrival <= time }
            let leadIn = visibleFixes.filter { $0.arrival < trial.cut }.map(\.point)
            let reference = replay.hiddenFixes.filter { $0.arrival <= time }.map(\.point)
            let after = visibleFixes.filter { $0.arrival >= trial.restore && $0.measured >= trial.restore }.map(\.point)
            let baselineEnd = replay.baselinePose(at: min(time, trial.restore))?.point
            let baseline = [replay.baselinePose(at: trial.cut)?.point, baselineEnd].compactMap { $0 }
            let last = min(time, replay.resumesAt ?? trial.restore)
            let coast = coastTrail(to: last)

            let leadInOverview = replay.fixes.filter { $0.arrival < trial.cut }.map(\.point)
            stroke(leadInOverview, in: context, extent: extent, color: DriftStyle.muted.opacity(0.19), width: 2)
            stroke(leadIn, in: context, extent: extent, color: DriftStyle.muted.opacity(0.65), width: 2)
            if showReference {
                stroke(leadIn.suffix(1) + reference, in: context, extent: extent,
                       color: DriftStyle.muted, width: 2, dash: [2, 6])
            }
            stroke(after, in: context, extent: extent, color: DriftStyle.muted.opacity(0.65), width: 2)
            stroke(baseline, in: context, extent: extent, color: DriftStyle.amber, width: 2, dash: [5, 5])
            stroke(coast, in: context, extent: extent, color: DriftStyle.mint.opacity(0.14), width: 8)
            stroke(coast, in: context, extent: extent, color: DriftStyle.mint, width: 3)
            mark(baselineEnd, in: context, extent: extent, color: DriftStyle.amber, radius: 3.5)
            if showReference { mark(reference.last, in: context, extent: extent, color: DriftStyle.muted, radius: 3.5) }

            switch replay.phase(at: time) {
            case .tracking, .recovered:
                mark(replay.lastAdmittedFix(at: time)?.point, in: context, extent: extent, color: DriftStyle.mint, radius: 6)
            case .coasting:
                mark(replay.coastPose(at: time)?.point, in: context, extent: extent, color: DriftStyle.mint, radius: 6)
            case .unavailable:
                mark(coast.last, in: context, extent: extent, color: DriftStyle.muted, radius: 4)
            }
        }
        .background(DriftStyle.background)
    }

    private func coastTrail(to end: Double) -> [ENPoint] {
        guard end >= trial.cut else { return [] }
        let ticks = stride(from: trial.cut, through: end, by: 0.2)
        var route = ticks.compactMap { replay.coastPose(at: $0)?.point }
        if let latest = replay.coastPose(at: end) { route.append(latest.point) }
        return route
    }

    private func drawGrid(in context: GraphicsContext, size: CGSize, extent: PlotExtent) {
        let stepM: Double = extent.scale >= 1 ? 25 : extent.scale >= 0.45 ? 50 : 100
        let step = stepM * extent.scale
        var grid = Path()
        for x in stride(from: size.width / 2 - ceil(size.width / 2 / step) * step, to: size.width, by: step) {
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: size.height / 2 - ceil(size.height / 2 / step) * step, to: size.height, by: step) {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(grid, with: .color(DriftStyle.border.opacity(0.55)), lineWidth: 0.75)
        let north = Text("N  ↑").font(.system(.caption2, design: .monospaced).weight(.semibold))
            .foregroundStyle(DriftStyle.muted)
        context.draw(north, at: CGPoint(x: size.width - 15, y: 19), anchor: .trailing)
        let y = size.height - 16
        let x = 15.0
        var scale = Path()
        scale.move(to: CGPoint(x: x, y: y - 4))
        scale.addLine(to: CGPoint(x: x, y: y))
        scale.addLine(to: CGPoint(x: x + step, y: y))
        scale.addLine(to: CGPoint(x: x + step, y: y - 4))
        context.stroke(scale, with: .color(DriftStyle.muted), lineWidth: 1)
        let label = Text("\(Int(stepM)) m").font(.system(.caption2, design: .monospaced))
            .foregroundStyle(DriftStyle.muted)
        context.draw(label, at: CGPoint(x: x + step / 2, y: y - 8), anchor: .bottom)
    }

    private func stroke(_ points: [ENPoint], in context: GraphicsContext, extent: PlotExtent,
                        color: Color, width: CGFloat, dash: [CGFloat] = []) {
        guard let first = points.first, points.count > 1 else { return }
        var path = Path()
        path.move(to: extent[first])
        for point in points.dropFirst() { path.addLine(to: extent[point]) }
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    private func mark(_ point: ENPoint?, in context: GraphicsContext, extent: PlotExtent, color: Color, radius: CGFloat) {
        guard let point else { return }
        let p = extent[point]
        let halo = radius + 5
        context.fill(Path(ellipseIn: CGRect(x: p.x - halo, y: p.y - halo, width: 2 * halo, height: 2 * halo)),
                     with: .color(color.opacity(0.16)))
        let dot = Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: 2 * radius, height: 2 * radius))
        context.fill(dot, with: .color(color))
        context.stroke(dot, with: .color(DriftStyle.background), lineWidth: 1.3)
    }
}

private struct PlotExtent {
    let center: ENPoint
    let scale: Double
    let size: CGSize

    init(points: [ENPoint], size: CGSize) {
        let east = points.map(\.east)
        let north = points.map(\.north)
        let minE = east.min() ?? 0, maxE = east.max() ?? 0
        let minN = north.min() ?? 0, maxN = north.max() ?? 0
        center = ENPoint(east: (minE + maxE) / 2, north: (minN + maxN) / 2)
        scale = min(max(Double(size.width) - 56, 20) / max(maxE - minE, 40),
                    max(Double(size.height) - 85, 20) / max(maxN - minN, 40))
        self.size = size
    }

    subscript(point: ENPoint) -> CGPoint {
        CGPoint(x: size.width / 2 + (point.east - center.east) * scale,
                y: size.height / 2 - (point.north - center.north) * scale)
    }
}
