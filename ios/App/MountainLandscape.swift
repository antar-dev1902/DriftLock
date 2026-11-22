#if os(macOS)
import SceneKit
import simd

func mountainEase(_ value: Float) -> Float {
    let t = min(1, max(0, value))
    return t * t * (3 - 2 * t)
}

struct MountainRoad {
    private let distances: [Float]
    let points: [SIMD3<Float>]
    var length: Float { distances.last ?? 0 }

    init(_ bends: [SIMD2<Float>], entry: SIMD2<Float>? = nil, exit: SIMD2<Float>? = nil) {
        var center: [SIMD2<Float>] = []
        for i in 0..<(bends.count - 1) {
            let start = bends[i]
            let end = bends[i + 1]
            let startTangent = i == 0 ? (entry ?? end - start) : (end - bends[i - 1]) * 0.5
            let endTangent = i == bends.count - 2 ? (exit ?? end - start) : (bends[i + 2] - start) * 0.5
            for step in 0..<40 {
                let t = Float(step) / 40
                let t2 = t * t
                let t3 = t2 * t
                let position = start * (2 * t3 - 3 * t2 + 1)
                    + startTangent * (t3 - 2 * t2 + t)
                    + end * (-2 * t3 + 3 * t2) + endTangent * (t3 - t2)
                center.append(position)
            }
        }
        center.append(bends[bends.count - 1])
        points = center.map { SIMD3($0.x, MountainLandscape.grade($0), $0.y) }
        var cumulative: [Float] = [0]
        for (a, b) in zip(points, points.dropFirst()) {
            cumulative.append(cumulative[cumulative.count - 1] + simd_distance(a, b))
        }
        distances = cumulative
    }

    func position(at distance: Float) -> SIMD3<Float> {
        let distance = min(length, max(0, distance))
        var low = 0
        var high = points.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if distances[mid] < distance { low = mid } else { high = mid }
        }
        let fraction = (distance - distances[low]) / (distances[high] - distances[low])
        return points[low] + (points[high] - points[low]) * fraction
    }
}

enum MountainDrive {
    private static let junction = SIMD2<Float>(-3, -5)
    private static let junctionHeading = SIMD2<Float>(3.4, -1.4)
    static let approach = MountainRoad([
        [-47, 15], [-40, 11], [-34, 13], [-29, 12], [-25, 5],
        [-20, 0], [-15, 2], [-10, 0], [-7, -3], junction
    ], exit: junctionHeading)
    static let main = MountainRoad([junction, [3, -8], [13, -8], [22, -3], [32, 0], [46, -3]], entry: junctionHeading)
    static let detours: [MountainRoute: MountainRoad] = [
        .ridge: MountainRoad([junction, [-1, -9], [-4, -15], [1, -21], [9, -21],
            [15, -15], [21, -16], [29, -12], [36, -7], [46, -3]], entry: junctionHeading),
        .valley: MountainRoad([junction, [1, -5.5], [4, 0], [3, 7], [9, 12], [16, 11],
            [21, 6], [28, 8], [35, 3], [46, -3]], entry: junctionHeading)
    ]
    struct Pose {
        let road: MountainRoad
        let distance: Float
        var position: SIMD3<Float> { road.position(at: distance) }
        var tangent: SIMD3<Float> { road.position(at: distance + 0.16) - road.position(at: distance - 0.16) }
    }

    static func pose(at time: Double, route: MountainRoute?) -> Pose {
        let junctionTime = MountainBeat.closure.time
        if time >= junctionTime, let route, let detour = detours[route] {
            let fraction = Float((time - junctionTime) / (MountainBeat.duration - junctionTime))
            return Pose(road: detour, distance: detour.length * travelProgress(fraction))
        }
        return Pose(road: approach, distance: approach.length * travelProgress(Float(time / junctionTime)))
    }

    // Smooth acceleration and braking at either end with a constant-speed middle.
    static func travelProgress(_ progress: Float) -> Float {
        let t = max(0, min(1, progress))
        let ramp: Float = 0.09
        if t < ramp { return t * t / (2 * ramp * (1 - ramp)) }
        if t > 1 - ramp {
            let remaining = 1 - t
            return 1 - remaining * remaining / (2 * ramp * (1 - ramp))
        }
        return (t - ramp / 2) / (1 - ramp)
    }

    static let roads = [approach, main] + MountainRoute.allCases.compactMap { detours[$0] }
}

final class MountainLandscape {
    static let step: Float = 0.36
    private static let columns = 405
    private static let rows = 313
    static let origin = SIMD2<Float>(-73, -61)
    private var heights: [Float] = []
    private var roadDistance: [Float]

    init(roads: [MountainRoad]) {
        let count = Self.rows * Self.columns
        roadDistance = Array(repeating: .infinity, count: count)
        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                heights.append(Self.elevation(at: Self.point(column, row)))
            }
        }
        for road in roads {
            for p in road.points {
                let grid = (SIMD2(p.x, p.z) - Self.origin) / Self.step
                let gx = Int(grid.x), gz = Int(grid.y)
                for row in (gz - 18)...(gz + 18) {
                    for column in (gx - 18)...(gx + 18) {
                        let index = row * Self.columns + column
                        let offset = SIMD2(Float(column), Float(row)) - grid
                        roadDistance[index] = min(roadDistance[index], simd_length_squared(offset) * Self.step * Self.step)
                    }
                }
            }
        }
        for i in heights.indices where roadDistance[i] < 40 {
            let p = Self.point(i % Self.columns, i / Self.columns)
            let blend = mountainEase((sqrt(roadDistance[i]) - 1.60) / 4.65)
            let roadbed = Self.grade(p) - 0.08
            heights[i] = roadbed + (heights[i] - roadbed) * blend
        }
    }

    static func grade(_ p: SIMD2<Float>) -> Float {
        3.1 + sin(p.x * 0.091) * 0.65
            + 6.3 * mountainEase((-p.y - 7) / 16)
            + 1.3 * mountainEase((p.y - 4) / 12)
    }

    func height(_ p: SIMD2<Float>) -> Float {
        let grid = (p - Self.origin) / Self.step
        let x = max(0, min(Self.columns - 2, Int(grid.x)))
        let z = max(0, min(Self.rows - 2, Int(grid.y)))
        let fraction = simd_clamp(grid - SIMD2(Float(x), Float(z)), .zero, SIMD2(repeating: 1))
        let index = z * Self.columns + x
        let a = heights[index], b = heights[index + 1]
        let c = heights[index + Self.columns], d = heights[index + Self.columns + 1]
        // Same diagonal as the mesh, so debris rests on the rendered surface.
        if fraction.x + fraction.y <= 1 {
            return a + (b - a) * fraction.x + (c - a) * fraction.y
        }
        return d + (c - d) * (1 - fraction.x) + (b - d) * (1 - fraction.y)
    }

    private static func point(_ column: Int, _ row: Int) -> SIMD2<Float> {
        origin + SIMD2(Float(column), Float(row)) * step
    }

    private static func elevation(at p: SIMD2<Float>) -> Float {
        let spine = -28 + sin(p.x * 0.115) * 5 + sin(p.x * 0.043) * 4
        let shoulders = 29 + sin(p.x * 0.090 + 0.8) * 6
        let north = max(0, 1 - abs(p.y - spine) / 26)
        let south = max(0, 1 - abs(p.y - shoulders) / 21)
        let buttress = noise(p * SIMD2(0.19, 0.055))
        let gully = abs(noise(p * SIMD2(0.30, 0.095) + SIMD2(19, 2)) * 2 - 1)
        let slope = max(north, south)
        let ridge = (14 + 10 * noise(p * 0.092)) * pow(north, 1.15)
            + (8 + 8 * noise(p * 0.081 + SIMD2(3, 8))) * pow(south, 1.45)
        let rock = (buttress * 8 + gully * 5.2
            + noise(p * 0.44) * 2.35 + noise(p * 1.12) * 0.9
            + noise(p * 2.36) * 0.37) * slope
        let broad = 1.2 + 1.7 * noise(p * 0.056)
        let edge = mountainEase((1.12 - simd_length(p / SIMD2(75, 61))) / 0.25)
        return (broad + ridge + rock) * edge + 0.3
    }

    func terrain() -> SCNNode {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var textureCoordinates: [CGPoint] = []
        var colors: [SIMD4<Float>] = []
        var indices: [Int32] = []
        vertices.reserveCapacity(heights.count)
        normals.reserveCapacity(heights.count)
        colors.reserveCapacity(heights.count)
        indices.reserveCapacity((Self.columns - 1) * (Self.rows - 1) * 6)
        for row in 0..<Self.rows {
            for column in 0..<Self.columns {
                let i = row * Self.columns + column
                let p = Self.point(column, row)
                let y = heights[i]
                vertices.append(SCNVector3(p.x, y, p.y))
                let dx = heights[row * Self.columns + min(column + 1, Self.columns - 1)]
                    - heights[row * Self.columns + max(0, column - 1)]
                let dz = heights[min(row + 1, Self.rows - 1) * Self.columns + column]
                    - heights[max(0, row - 1) * Self.columns + column]
                let normal = simd_normalize(SIMD3(-dx, 2 * Self.step, -dz))
                normals.append(SCNVector3(normal))
                textureCoordinates.append(CGPoint(x: CGFloat(p.x / 18), y: CGFloat(p.y / 18)))
                let variation = Self.noise(p * 0.83) - 0.5
                let bands = sin(y * 1.85 + p.x * 0.43 + Self.noise(p * 0.33) * 4) * 0.069
                let exposed = mountainEase((0.93 - normal.y) * 2.0 + (y - 12) * 0.037)
                let vegetation = SIMD3<Float>(0.23, 0.34, 0.18) + SIMD3(repeating: variation * 0.19)
                let stone = SIMD3<Float>(0.48, 0.45, 0.39) + SIMD3(repeating: variation * 0.26 + bands)
                var color = vegetation + (stone - vegetation) * exposed
                let scree = mountainEase((y - 23 + Self.noise(p * 0.12) * 4) / 8)
                color += (SIMD3<Float>(0.71, 0.71, 0.68) - color) * scree
                let roadside = 1 - mountainEase((sqrt(roadDistance[i]) - 1.0) / 1.8)
                color += (SIMD3<Float>(0.47, 0.41, 0.33) - color) * roadside
                colors.append(SIMD4(color.x, color.y, color.z, 1))
                if row + 1 < Self.rows, column + 1 < Self.columns {
                    let a = Int32(i), b = a + Int32(Self.columns)
                    indices += [a, b, a + 1, a + 1, b, b + 1]
                }
            }
        }
        let mesh = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals), SCNGeometrySource(textureCoordinates: textureCoordinates), Self.colorSource(colors)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let surface = SCNMaterial()
        surface.lightingModel = .lambert
        surface.diffuse.contents = Self.groundTexture()
        surface.diffuse.wrapS = .repeat
        surface.diffuse.wrapT = .repeat
        surface.diffuse.mipFilter = .linear
        mesh.firstMaterial = surface
        return SCNNode(geometry: mesh)
    }

    func forest() -> SCNNode {
        var vertices: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        var indices: [Int32] = []
        for row in stride(from: 10, to: Self.rows - 10, by: 4) {
            for column in stride(from: 10, to: Self.columns - 10, by: 4) {
                let p = Self.point(column, row)
                let chance = Self.random(column, row)
                let index = row * Self.columns + column
                let y = heights[index]
                let grove = Self.noise(p * 0.15)
                guard roadDistance[index] > 8, y > 2.3, y < 17, chance < grove * 0.7,
                      !(p.x > -2 && p.x < 11 && p.y > -21 && p.y < -6) else { continue }
                let x = p.x + (chance - 0.5) * 0.8
                let z = p.y + (Self.random(row, column) - 0.5) * 0.8
                let ground = height(SIMD2(x, z))
                let top = 0.64 + Self.random(column + 31, row) * 0.96
                let shade = 0.63 + chance * 0.9
                let sides = 9
                for tier in 0..<4 {
                    let base = Int32(vertices.count)
                    let tierOffset = Float(tier) * 0.17
                    let radius = top * (0.28 - tierOffset * 0.35)
                    vertices.append(SCNVector3(x, ground + top * (0.56 + tierOffset), z))
                    colors.append(SIMD4(0.20 * shade, 0.31 * shade, 0.13 * shade, 1))
                    for side in 0..<sides {
                        let angle = (Float(side) / Float(sides) + chance + Float(tier) * 0.12) * 2 * .pi
                        let ragged = Self.random(index + side, 65 + tier)
                        let reach = radius * (0.7 + 0.47 * ragged)
                        let tip = ground + top * (0.15 + tierOffset + ragged * 0.11)
                        vertices.append(SCNVector3(x + cos(angle) * reach, tip, z + sin(angle) * reach))
                        let light = 0.64 + ragged * 0.39
                        colors.append(SIMD4(0.11 * shade * light, 0.21 * shade * light, 0.09 * shade * light, 1))
                        indices += [base, base + 1 + Int32(side), base + 1 + Int32((side + 1) % sides)]
                    }
                }
            }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), Self.colorSource(colors)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.firstMaterial = material
        return SCNNode(geometry: geometry)
    }

    private static func groundTexture() -> CGImage? {
        let size = 512
        var pixels: [UInt8] = []
        pixels.reserveCapacity(size * size)
        for y in 0..<size {
            for x in 0..<size {
                let p = SIMD2(Float(x), Float(y))
                let strata = noise(p * SIMD2(0.04, 0.16)) * 0.20
                let grain = random(x + 2048, y) * 0.13
                let chips = noise(p * 0.31) * 0.19
                pixels.append(UInt8((0.48 + strata + grain + chips) * 255))
            }
        }
        guard let data = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: size, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: data, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    static func colorSource(_ colors: [SIMD4<Float>]) -> SCNGeometrySource {
        SCNGeometrySource(data: colors.withUnsafeBytes { Data($0) }, semantic: .color,
            vectorCount: colors.count, usesFloatComponents: true, componentsPerVector: 4,
            bytesPerComponent: 4, dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride)
    }

    static func random(_ x: Int, _ z: Int) -> Float {
        var hash = UInt32(truncatingIfNeeded: x) &* 0x9e3779b1
            ^ UInt32(truncatingIfNeeded: z) &* 0x85ebca77
        hash ^= hash >> 16
        hash = hash &* 0x7feb352d
        hash ^= hash >> 15
        return Float(hash & 0xffff) / 65535
    }

    private static func noise(_ p: SIMD2<Float>) -> Float {
        let x = Int(floor(p.x)), z = Int(floor(p.y))
        let u = mountainEase(p.x - Float(x)), v = mountainEase(p.y - Float(z))
        let a = random(x, z), b = random(x + 1, z)
        let c = random(x, z + 1), d = random(x + 1, z + 1)
        let near = a + (b - a) * u
        return near + (c + (d - c) * u - near) * v
    }
}
#endif
