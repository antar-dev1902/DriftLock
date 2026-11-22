#if os(macOS)
import SwiftUI
import simd

struct MapProjection {
    let size: CGSize
    let center: SIMD2<Float>
    let scale: CGFloat

    func point(_ world: SIMD2<Float>) -> CGPoint {
        CGPoint(x: size.width / 2 + CGFloat(world.x - center.x) * scale,
                y: size.height / 2 + CGFloat(world.y - center.y) * scale)
    }

    func point(_ world: SIMD3<Float>) -> CGPoint { point(SIMD2(world.x, world.z)) }

    func path(_ road: MountainRoad) -> Path {
        line(road.points.map { SIMD2($0.x, $0.z) })
    }

    func line(_ coordinates: [SIMD2<Float>]) -> Path {
        Path { path in path.addLines(coordinates.map(point)) }
    }
}

enum MapStyle {
    static let background = Color(red: 0.93, green: 0.95, blue: 0.89)
    static let controls = Color(red: 0.94, green: 0.96, blue: 0.97)
    static let ink = Color(red: 0.12, green: 0.20, blue: 0.24)
    static let muted = Color(red: 0.32, green: 0.39, blue: 0.42)
    static let route = Color(red: 0.04, green: 0.36, blue: 0.82)
    static let routeEdge = Color(red: 0.05, green: 0.26, blue: 0.59)
    static let saved = Color(red: 0.29, green: 0.44, blue: 0.54)
    static let warning = Color(red: 0.63, green: 0.28, blue: 0.08)
    static let guidance = Color(red: 0.06, green: 0.32, blue: 0.28)
    static let river = Color(red: 0.67, green: 0.82, blue: 0.87)

    // The illustrative map uses a scale of 55 simulated meters per scene unit.
    static let metresPerUnit: Float = 55
    static func distance(_ units: Float) -> String {
        let meters = units * metresPerUnit
        if meters < 1000 {
            return "\(Int((meters / 10).rounded()) * 10) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}

struct NavigationMap: View {
    let projection: MapProjection
    let pose: MountainDrive.Pose
    let selected: MountainRoute?
    let blocked: Bool
    let estimated: Bool

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MapStyle.background))
            if let relief = MapAtlas.relief {
                let topLeft = projection.point(MapAtlas.northwest)
                let bottomRight = projection.point(MapAtlas.southeast)
                let frame = CGRect(x: topLeft.x, y: topLeft.y,
                                   width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
                context.draw(Image(decorative: relief, scale: 1), in: frame)
            }
            drawGeography(in: context)
            drawRoads(in: context)
            drawLocations(in: context)
            drawVehicle(in: context)
            drawScale(in: context)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(estimated ? "Map showing estimated vehicle position" : "Map showing vehicle position")
    }

    private func drawGeography(in context: GraphicsContext) {
        let river = projection.line(MapAtlas.creek)
        context.stroke(river, with: .color(MapStyle.river), style: StrokeStyle(
            lineWidth: max(3, projection.scale * 0.5), lineCap: .round, lineJoin: .round))
        for village in MapAtlas.settlements {
            let outline = projection.line(village.boundary)
            context.fill(outline, with: .color(Color(red: 0.95, green: 0.92, blue: 0.85).opacity(0.9)))
            for building in village.buildings {
                let center = projection.point(building)
                let width = clamped(projection.scale * 0.47, low: 3, high: 13)
                let rect = CGRect(x: center.x - width / 2, y: center.y - width * 0.34,
                                  width: width, height: width * 0.68)
                let path = Path(roundedRect: rect, cornerRadius: 1)
                context.fill(path, with: .color(Color(red: 0.82, green: 0.76, blue: 0.68)))
            }
        }
    }

    private func drawRoads(in context: GraphicsContext) {
        for line in MapAtlas.localRoads {
            let road = projection.path(line)
            context.stroke(road, with: .color(Color(red: 0.75, green: 0.76, blue: 0.70)), style: StrokeStyle(
                lineWidth: 5, lineCap: .round, lineJoin: .round))
            context.stroke(road, with: .color(.white), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
        }
        for road in MountainDrive.roads {
            let path = projection.path(road)
            context.stroke(path, with: .color(Color(red: 0.68, green: 0.71, blue: 0.66)), style: StrokeStyle(
                lineWidth: 7, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }

        if blocked {
            for option in MountainRoute.allCases where option != selected {
                if let road = MountainDrive.detours[option] {
                    context.stroke(projection.path(road), with: .color(MapStyle.saved.opacity(0.85)), style: StrokeStyle(
                        lineWidth: 4.5, lineCap: .round, lineJoin: .round, dash: [3, 7]))
                }
            }
            context.stroke(projection.path(MountainDrive.main), with: .color(MapStyle.warning.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [5, 7]))
        }

        let active: Path
        if let selected, let detour = MountainDrive.detours[selected] {
            active = projection.path(detour)
        } else if blocked {
            active = projection.path(MountainDrive.approach)
        } else {
            let continuousRoute = MountainDrive.approach.points + MountainDrive.main.points.dropFirst()
            active = projection.line(continuousRoute.map { SIMD2($0.x, $0.z) })
        }
        context.stroke(active, with: .color(.white), style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
        context.stroke(active, with: .color(MapStyle.routeEdge), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
        context.stroke(active, with: .color(MapStyle.route), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
    }

    private func drawLocations(in context: GraphicsContext) {
        label("Foothill Village", at: [-51, 10], color: MapStyle.ink, size: 14, weight: .semibold, context: context)
        label("Pinecrest Pass", at: [48, 4], color: MapStyle.ink, size: 14, weight: .semibold, context: context)
        label("Cedar Ridge", at: [-12, -30], color: MapStyle.guidance, size: 13, weight: .medium, context: context)
        label("Cedar Creek", at: [24, 27], color: MapStyle.saved, size: 12, weight: .medium, context: context)
        label("Foothill Road", at: [-30, 7], color: MapStyle.muted, size: 11, weight: .medium, context: context)
        if blocked || projection.scale > 10.5 {
            label("Ridge road", at: [12, -24], color: MapStyle.muted, size: 11, weight: .medium, context: context)
            label("Valley road", at: [13, 16], color: MapStyle.muted, size: 11, weight: .medium, context: context)
        }

        let destination = projection.point(MountainDrive.main.position(at: MountainDrive.main.length))
        drawBadge(at: destination, icon: "flag.checkered", color: MapStyle.guidance, context: context)
        if pose.distance > 2 {
            let origin = projection.point(MountainDrive.approach.position(at: 0))
            context.fill(circle(at: origin, diameter: 9), with: .color(.white))
            context.stroke(circle(at: origin, diameter: 9), with: .color(MapStyle.routeEdge), lineWidth: 2)
        }
        if blocked {
            let closure = projection.point(MountainDrive.main.position(at: 9.5))
            drawBadge(at: closure, icon: "minus", color: MapStyle.warning, context: context)
        }
    }

    private func drawVehicle(in context: GraphicsContext) {
        let point = projection.point(pose.position)
        let vector = pose.tangent
        let heading = atan2(Double(vector.x), -Double(vector.z))
        let accent = estimated ? MapStyle.warning : MapStyle.route
        if estimated {
            let area = circle(at: point, diameter: 74)
            context.fill(area, with: .color(accent.opacity(0.11)))
            context.stroke(area, with: .color(accent.opacity(0.49)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
        }
        var shadow = context
        shadow.addFilter(.shadow(color: MapStyle.ink.opacity(0.28), radius: 5, y: 3))
        shadow.fill(circle(at: point, diameter: 33), with: .color(.white))
        context.fill(circle(at: point, diameter: 28), with: .color(MapStyle.route))

        var direction = context
        direction.translateBy(x: point.x, y: point.y)
        direction.rotate(by: .radians(heading))
        direction.draw(Text(Image(systemName: "location.north.fill")).font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white), at: .zero)
    }

    private func drawScale(in context: GraphicsContext) {
        let meters = projection.scale > 12 ? 250 : 500
        let length = CGFloat(Float(meters) / MapStyle.metresPerUnit) * projection.scale
        let right = projection.size.width - 120
        let left = right - length
        let baseline = projection.size.height - 28
        let scale = Path { path in
            path.addLines([CGPoint(x: left, y: baseline - 5), CGPoint(x: left, y: baseline),
                           CGPoint(x: right, y: baseline), CGPoint(x: right, y: baseline - 5)])
        }
        context.stroke(scale, with: .color(.white.opacity(0.89)), lineWidth: 4)
        context.stroke(scale, with: .color(MapStyle.ink), lineWidth: 1.5)
        context.draw(Text("\(meters) m").font(.system(size: 10, weight: .semibold))
            .foregroundStyle(MapStyle.ink), at: CGPoint(x: (left + right) / 2, y: baseline - 10))
    }

    private func drawBadge(at point: CGPoint, icon: String, color: Color, context: GraphicsContext) {
        context.fill(circle(at: point, diameter: 23), with: .color(.white))
        context.fill(circle(at: point, diameter: 19), with: .color(color))
        context.draw(Text(Image(systemName: icon)).font(.system(size: 9, weight: .bold)).foregroundStyle(.white), at: point)
    }

    private func label(_ title: String, at world: SIMD2<Float>, color: Color, size: CGFloat,
                       weight: Font.Weight, context: GraphicsContext) {
        let point = projection.point(world)
        let resolved = context.resolve(Text(title).font(.system(size: size, weight: weight)).foregroundStyle(color))
        let outline = context.resolve(Text(title).font(.system(size: size, weight: weight)).foregroundStyle(.white))
        for offset in [CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: -1), CGPoint(x: 0, y: 1)] {
            context.draw(outline, at: CGPoint(x: point.x + offset.x, y: point.y + offset.y))
        }
        context.draw(resolved, at: point)
    }

    private func circle(at point: CGPoint, diameter: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2,
                              width: diameter, height: diameter))
    }

    private func clamped(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        min(max(value, low), high)
    }
}

private enum MapAtlas {
    static let northwest = SIMD2<Float>(-95, -70)
    static let southeast = SIMD2<Float>(96, 71)
    static let creek: [SIMD2<Float>] = [
        [-95, 37], [-80, 38], [-68, 35], [-59, 34], [-55, 29], [-47, 27],
        [-38, 24], [-26, 26], [-17, 30], [-7, 32], [3, 31], [14, 28],
        [27, 29], [39, 24], [47, 19], [53, 9], [59, 5], [69, 7], [80, 9], [96, 6]
    ]
    static let localRoads = [
        MountainRoad([[-88, 20], [-68, 22], [-57, 21], [-51, 18], [-47, 15]]),
        MountainRoad([[-57, 21], [-56, 25], [-49, 25], [-43, 22], [-40, 19], [-39, 11]]),
        MountainRoad([[-49, 25], [-45, 30], [-36, 35], [-26, 35], [-19, 38], [-12, 44]]),
        MountainRoad([[-68, 22], [-66, 13], [-59, 8], [-48, 5], [-43, 5], [-40, 11]]),
        MountainRoad([[-28, 11], [-30, 19], [-24, 22], [-19, 22], [-17, 27], [-12, 32]]),
        MountainRoad([[46, -3], [51, -3], [57, -1], [63, -4], [72, -5], [86, -1]]),
        MountainRoad([[51, -3], [50, -11], [47, -14], [50, -20], [59, -22], [65, -25], [68, -32]]),
        MountainRoad([[57, -1], [56, 3], [58, 7], [53, 12], [52, 16], [48, 21], [45, 26]]),
        MountainRoad([[36, -7], [38, -13], [42, -15], [47, -14]])
    ]

    static let settlements: [(boundary: [SIMD2<Float>], buildings: [SIMD2<Float>])] = [
        ([[-61, 23], [-60, 12], [-48, 7], [-43, 8], [-38, 13], [-39, 23], [-45, 28], [-53, 29], [-61, 23]],
         [[-55, 17], [-53, 18], [-50, 16], [-48.5, 17.4], [-47, 12], [-45, 13.4], [-43, 15.2],
          [-57, 23], [-54, 23.8], [-51, 23.6], [-48, 24], [-45.7, 23], [-43, 19.3], [-41, 18.8]]),
        ([[45, -15], [53, -16], [59, -11], [65, -7], [63, 2], [57, 8], [49, 7], [45, 3], [45, -15]],
         [[48, -6], [51, -6.5], [53, -5], [55, -3.9], [57, -3], [58.5, -6],
          [52, -1.2], [54, 0.4], [54, 2.1], [56, 4.1], [59, 2.7], [60.5, -1]])
    ]

    static let relief: CGImage? = {
        let land = MountainLandscape(roads: MountainDrive.roads)
        let width = 928, height = 685
        var pixels: [UInt8] = []
        pixels.reserveCapacity(width * height * 3)
        for row in 0..<height {
            let z = northwest.y + Float(row) / Float(height - 1) * (southeast.y - northwest.y)
            for column in 0..<width {
                let x = northwest.x + Float(column) / Float(width - 1) * (southeast.x - northwest.x)
                let elevation = land.height([x, z])
                let ridge = mountainEase(elevation / 24)
                let shade = min(max((elevation - land.height([x - 0.6, z - 0.45])) * 0.28, -1), 1)
                let contourLevel = elevation / 3
                let contour = (1 - mountainEase(abs(contourLevel - contourLevel.rounded()) / 0.045)) * ridge
                pixels.append(UInt8(237 - ridge * 49 - shade * 7 - contour * 8))
                pixels.append(UInt8(242 - ridge * 34 - shade * 6 - contour * 7))
                pixels.append(UInt8(225 - ridge * 47 - shade * 7 - contour * 8))
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 24,
                       bytesPerRow: width * 3, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }()
}
#endif
