#if os(macOS)
import SwiftUI
import SceneKit
import QuartzCore
import simd

struct MountainPlayback: Equatable {
    var elapsed = 0.0
    var startedAt: CFTimeInterval?
    var route: MountainRoute?

    var limit: Double { route == nil ? MountainBeat.closure.time : MountainBeat.duration }

    func time(at now: CFTimeInterval) -> Double {
        min(limit, elapsed + (startedAt.map { max(0, now - $0) } ?? 0))
    }
}

struct MountainMap: NSViewRepresentable, Equatable {
    let playback: MountainPlayback
    let reducedMotion: Bool

    func makeCoordinator() -> Renderer { Renderer() }

    func makeNSView(context: Context) -> SCNView {
        let view = SceneView()
        view.scene = context.coordinator.landscape.scene
        view.pointOfView = context.coordinator.landscape.camera
        view.antialiasingMode = .multisampling4X
        view.backgroundColor = .clear
        view.layer?.isOpaque = false
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        context.coordinator.attach(to: view)
        view.didResize = { [weak renderer = context.coordinator] in
            renderer?.draw(at: CACurrentMediaTime())
        }
        return view
    }

    func updateNSView(_ view: SCNView, context: Context) {
        context.coordinator.playback = playback
        context.coordinator.reducedMotion = reducedMotion
        context.coordinator.draw(at: CACurrentMediaTime())
    }

    static func dismantleNSView(_ view: SCNView, coordinator: Renderer) {
        coordinator.displayLink?.invalidate()
    }

    private final class SceneView: SCNView {
        var didResize: (() -> Void)?

        private var lastSize = CGSize.zero

        override func layout() {
            super.layout()
            guard bounds.size != lastSize else { return }
            lastSize = bounds.size
            didResize?()
        }
    }

    @MainActor final class Renderer: NSObject {
        let landscape = MountainScene()
        var playback = MountainPlayback()
        var reducedMotion = false
        weak var view: SCNView?
        var displayLink: CADisplayLink?

        func attach(to view: SCNView) {
            self.view = view
            let link = view.displayLink(target: self, selector: #selector(frame(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc private func frame(_ link: CADisplayLink) {
            draw(at: link.targetTimestamp)
        }

        func draw(at timestamp: CFTimeInterval) {
            guard let view else { return }
            let time = playback.time(at: timestamp)
            landscape.render(time, route: playback.route, reducedMotion: reducedMotion,
                             aspect: Float(view.bounds.width / max(1, view.bounds.height)))
            view.needsDisplay = true
            displayLink?.isPaused = playback.startedAt == nil || time >= playback.limit
        }
    }
}

final class MountainScene {
    let scene = SCNScene()
    let camera = SCNNode()
    let car = SCNNode()
    private let halo = SCNNode()
    private let shadow = SCNNode()
    private let slopeScar: SCNNode
    private let debris: [Debris]
    private let dust: [SCNNode]
    private let land: MountainLandscape
    private let routeLines: [MountainRoute: SCNNode]
    private let mainLine: SCNNode
    private var lastSlideTime: Float?
    private var displayedRoute: MountainRoute?
    private var lastReducedMotion: Bool?
    private var showingClosure = false

    private static let active = NSColor(srgbRed: 0.15, green: 0.68, blue: 0.95, alpha: 1)
    private static let alternate = NSColor(srgbRed: 0.58, green: 0.83, blue: 0.69, alpha: 1)
    private static let blocked = NSColor(srgbRed: 0.94, green: 0.54, blue: 0.23, alpha: 1)

    init() {
        let landscape = MountainLandscape(roads: MountainDrive.roads)
        land = landscape
        let terrain = landscape.terrain()
        slopeScar = Self.scar(on: landscape)
        debris = (0..<72).map { Debris(index: $0, land: landscape) }
        dust = Self.makeDust()
        routeLines = MountainDrive.detours.mapValues { Self.ribbon($0.points, width: 0.12, lift: 0.055, color: Self.alternate) }
        mainLine = Self.ribbon(MountainDrive.main.points, width: 0.13, lift: 0.055, color: Self.active)

        scene.background.contents = NSColor.clear
        let root = scene.rootNode
        root.addChildNode(terrain)
        root.addChildNode(landscape.forest())
        for path in MountainDrive.roads {
            root.addChildNode(Self.ribbon(path.points, width: 1.40, lift: 0.005,
                color: NSColor(srgbRed: 0.62, green: 0.55, blue: 0.43, alpha: 1)))
            root.addChildNode(Self.ribbon(path.points, width: 1.14, lift: 0.035, color: NSColor(calibratedWhite: 0.21, alpha: 1)))
            for side: Float in [-1, 1] {
                root.addChildNode(Self.ribbon(path.points, width: 0.028, lift: 0.048,
                    offset: side * 0.99, color: NSColor(calibratedWhite: 0.84, alpha: 1)))
            }
        }
        root.addChildNode(Self.ribbon(MountainDrive.approach.points, width: 0.13, lift: 0.052, color: Self.active))
        root.addChildNode(mainLine)
        routeLines.values.forEach(root.addChildNode)
        root.addChildNode(slopeScar)
        debris.forEach { root.addChildNode($0.node) }
        dust.forEach(root.addChildNode)

        Self.buildSUV(in: car)
        root.addChildNode(car)
        let shadowGeometry = SCNPlane(width: 2.3, height: 2.9)
        shadowGeometry.firstMaterial = Self.material(Self.radialImage(color: NSColor.black), lit: false)
        shadowGeometry.firstMaterial?.writesToDepthBuffer = false
        shadow.geometry = shadowGeometry
        shadow.eulerAngles.x = -.pi / 2
        root.addChildNode(shadow)
        let ring = SCNTorus(ringRadius: 1.92, pipeRadius: 0.028)
        ring.firstMaterial = Self.material(Self.blocked.withAlphaComponent(0.82), lit: false)
        halo.geometry = ring
        root.addChildNode(halo)

        let sunlight = SCNNode()
        sunlight.light = SCNLight()
        sunlight.light?.type = .directional
        sunlight.light?.intensity = 860
        sunlight.light?.color = NSColor(srgbRed: 1, green: 0.94, blue: 0.85, alpha: 1)
        sunlight.eulerAngles = SCNVector3(-0.89, -0.77, 0)
        root.addChildNode(sunlight)
        let sky = SCNNode()
        sky.light = SCNLight()
        sky.light?.type = .ambient
        sky.light?.intensity = 540
        sky.light?.color = NSColor(srgbRed: 0.85, green: 0.91, blue: 1, alpha: 1)
        root.addChildNode(sky)

        let lens = SCNCamera()
        lens.fieldOfView = 42
        lens.zNear = 0.25
        lens.zFar = 410
        camera.camera = lens
        root.addChildNode(camera)
    }

    func render(_ elapsed: Double, route: MountainRoute?, reducedMotion: Bool, aspect: Float) {
        let time = Float(elapsed)
        let onDetour = elapsed >= MountainBeat.closure.time && route != nil
        let pose = MountainDrive.pose(at: elapsed, route: route)
        let p = pose.position
        let tangent = pose.tangent
        let yaw = atan2(tangent.x, tangent.z)
        car.simdPosition = p + SIMD3(0, 0.04, 0)
        car.eulerAngles = SCNVector3(-atan2(tangent.y, hypot(tangent.x, tangent.z)), yaw, 0)
        shadow.simdPosition = p + SIMD3(0, 0.06, 0)
        shadow.eulerAngles.z = CGFloat(-yaw)
        halo.simdPosition = p + SIMD3(0, 0.24, 0)
        halo.simdScale = SIMD3(repeating: 1 + max(0, time - 10) * 0.023)
        halo.isHidden = time < 10 || elapsed >= MountainBeat.recovery.time

        let slideTime = min(max(time, 18.5), 26)
        if slideTime != lastSlideTime || reducedMotion != lastReducedMotion {
            renderSlide(slideTime, reducedMotion: reducedMotion)
            lastSlideTime = slideTime
            lastReducedMotion = reducedMotion
        }

        let activeDetour = onDetour ? route : nil
        let roadClosed = time >= 22.8
        if activeDetour != displayedRoute {
            displayedRoute = activeDetour
            for (choice, node) in routeLines {
                node.geometry?.firstMaterial?.diffuse.contents = choice == activeDetour ? Self.active : Self.alternate
                node.opacity = activeDetour == nil || choice == activeDetour ? 1 : 0.4
            }
            mainLine.opacity = onDetour ? 0.45 : 1
        }
        if roadClosed != showingClosure {
            showingClosure = roadClosed
            mainLine.geometry?.firstMaterial?.diffuse.contents = roadClosed ? Self.blocked : Self.active
        }

        let zoomIn = Self.cameraEase(time / 6.5)
        let zoomOut = Self.cameraEase((time - 51) / 4)
        let follow = reducedMotion ? 0 : zoomIn * (1 - zoomOut)
        let reveal = mountainEase((time - 16.5) / 3) * (1 - mountainEase((time - 24) / 5))
        let overview = SIMD3<Float>(0, 5, -4)
        let lookAhead = pose.road.position(at: pose.distance + 3.3)
        let incident = SIMD3<Float>(1.0, 6, -9.8)
        let slideFraming = reveal * 0.66
        let chase = lookAhead + (incident - lookAhead) * slideFraming
        let focus = overview + (chase - overview) * follow
        let viewDistance = max(1, 1.37 / max(0.55, aspect))
        let wideOffset = SIMD3<Float>(-25, 142, 85) * viewDistance
        let openingLift = 1 - Self.cameraEase((time - 6.5) / 3.5)
        let chaseOffset = SIMD3<Float>(-8, 20 + openingLift * 15 + reveal * 5,
                                       14 - openingLift * 6 + reveal * 8)
        let farDistance = simd_length(wideOffset)
        let nearDistance = simd_length(chaseOffset)
        // Ease in log distance so perspective magnification changes steadily through the dive.
        let distanceScale = farDistance * pow(nearDistance / farDistance, follow)
        let viewDirection = simd_normalize(simd_mix(simd_normalize(wideOffset), simd_normalize(chaseOffset),
                                                    SIMD3(repeating: follow)))
        var eye = focus + viewDirection * distanceScale
        var minimumHeight: Float = -.infinity
        for step in 2...24 {
            let t = Float(step) / 25
            let sample = p + (eye - p) * t
            let ground = land.height([sample.x, sample.z])
            let clearance = 0.80 + 1.16 * mountainEase(t / 0.23)
            minimumHeight = max(minimumHeight, p.y + (ground + clearance - p.y) / t)
        }
        // Blend over a height band so engaging terrain clearance does not jerk the camera.
        let clearanceBand: Float = 2
        let difference = minimumHeight - eye.y
        let blend = max(0, clearanceBand - abs(difference)) / clearanceBand
        eye.y += max(0, difference) + blend * blend * clearanceBand / 4
        camera.simdPosition = eye
        camera.look(at: SCNVector3(focus))
    }

    private static func cameraEase(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t * t * t * (10 + t * (-15 + 6 * t))
    }

    private static func buildSUV(in car: SCNNode) {
        let paint = material(NSColor(srgbRed: 0.89, green: 0.33, blue: 0.10, alpha: 1))
        let black = material(NSColor(calibratedWhite: 0.11, alpha: 1))
        let glass = material(NSColor(srgbRed: 0.18, green: 0.28, blue: 0.33, alpha: 1))
        let metal = material(NSColor(calibratedWhite: 0.70, alpha: 1))
        let lamp = material(NSColor(srgbRed: 1, green: 0.95, blue: 0.78, alpha: 1), lit: false)
        let tail = material(NSColor(srgbRed: 0.94, green: 0.10, blue: 0.07, alpha: 1), lit: false)
        func part(_ size: SIMD3<Float>, at position: SIMD3<Float>, radius: CGFloat, surface: SCNMaterial) {
            let mesh = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: radius)
            mesh.firstMaterial = surface
            let node = SCNNode(geometry: mesh)
            node.simdPosition = position
            car.addChildNode(node)
        }
        part([1.16, 0.42, 1.96], at: [0, 0.47, 0], radius: 0.12, surface: paint)
        part([1.12, 0.23, 0.62], at: [0, 0.63, 0.63], radius: 0.08, surface: paint)
        part([0.97, 0.42, 1.14], at: [0, 0.79, -0.27], radius: 0.13, surface: glass)
        part([0.94, 0.11, 0.99], at: [0, 1.00, -0.30], radius: 0.045, surface: paint)
        part([1.18, 0.15, 0.10], at: [0, 0.36, 1.00], radius: 0.03, surface: black)
        part([0.50, 0.16, 0.03], at: [0, 0.56, 0.985], radius: 0.015, surface: black)
        part([1.13, 0.15, 0.09], at: [0, 0.39, -0.99], radius: 0.03, surface: black)
        for side: Float in [-1, 1] {
            part([0.035, 0.075, 0.94], at: [side * 0.34, 1.07, -0.31], radius: 0.012, surface: black)
            part([0.19, 0.10, 0.045], at: [side * 0.41, 0.57, 0.968], radius: 0.025, surface: lamp)
            part([0.17, 0.11, 0.05], at: [side * 0.43, 0.57, -0.966], radius: 0.022, surface: tail)
            part([0.15, 0.11, 0.13], at: [side * 0.55, 0.78, 0.19], radius: 0.03, surface: black)
            for axle: Float in [-0.61, 0.63] {
                for (radius, width, offset, surface): (CGFloat, CGFloat, Float, SCNMaterial) in [
                    (0.25, 0.18, 0.55, black), (0.14, 0.026, 0.65, metal)
                ] {
                    let mesh = SCNCylinder(radius: radius, height: width)
                    mesh.radialSegmentCount = 16
                    mesh.firstMaterial = surface
                    let wheel = SCNNode(geometry: mesh)
                    wheel.eulerAngles.z = .pi / 2
                    wheel.simdPosition = [side * offset, 0.25, axle]
                    car.addChildNode(wheel)
                }
            }
        }
    }

    private func renderSlide(_ time: Float, reducedMotion: Bool) {
        let slideTime = reducedMotion ? (time < 24 ? Float(16) : 26) : time
        slopeScar.opacity = CGFloat(mountainEase((slideTime - 18.4) / 2.5))
        for rock in debris {
            rock.update(at: slideTime, on: land)
        }
        for (i, cloud) in dust.enumerated() {
            let age = slideTime - 19.0 - Float(i) * 0.22
            let t = max(0, age)
            let opacity = mountainEase(age / 0.5) * (1 - mountainEase((age - 0.6) / 3.1))
            cloud.isHidden = opacity < 0.01
            guard !cloud.isHidden else { continue }
            let x = 3.7 + (MountainLandscape.random(i, 45) - 0.5) * 4.2 + t * 0.75
            let z = -15.0 + Float(i) * 0.46 + t * 0.53
            cloud.simdPosition = [x, land.height([x, z]) + 0.5 + t * 0.82, z]
            cloud.simdScale = SIMD3(repeating: 1.3 + t * 1.17)
            cloud.opacity = CGFloat(opacity * 0.48)
        }
    }

    private static func scar(on land: MountainLandscape) -> SCNNode {
        var vertices: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        var indices: [Int32] = []
        let columns = 24
        for row in 0..<29 {
            let z = MountainLandscape.origin.y + Float(120 + row) * MountainLandscape.step
            let runout = mountainEase((z + 17.8) / 10)
            let center = 4.35 + sin(runout * .pi) * 0.64
            for column in 0..<columns {
                let x = MountainLandscape.origin.x + Float(203 + column) * MountainLandscape.step
                let grain = MountainLandscape.random(column, row + 18)
                let width = 0.50 + runout * 2.3 + grain * 0.47
                let edge = mountainEase((width - abs(x - center)) / 1.05)
                let apron = mountainEase((z + 17.8) / 1.5) * (1 - mountainEase((z + 8.8) / 1.85))
                let tone = grain * 0.15
                vertices.append(SCNVector3(x, land.height([x, z]) + 0.018, z))
                colors.append(SIMD4(0.39 + tone, 0.29 + tone, 0.19 + tone, edge * apron * 0.88))
                if row > 0, column > 0 {
                    let a = Int32(vertices.count - 1), offset = Int32(columns)
                    indices += [a - offset - 1, a - 1, a - offset, a - offset, a - 1, a]
                }
            }
        }
        let mesh = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                                          MountainLandscape.colorSource(colors)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let surface = material(NSColor.white, lit: false)
        surface.writesToDepthBuffer = false
        mesh.firstMaterial = surface
        return SCNNode(geometry: mesh)
    }

    private struct Debris {
        let node: SCNNode
        let start: SIMD2<Float>
        let end: SIMD2<Float>
        let radius: Float
        let release: Float
        let duration: Float
        let spin: Float

        init(index: Int, land: MountainLandscape) {
            func sample(_ seed: Int) -> Float { MountainLandscape.random(index + 73, seed) }
            let spread = sample(1) - 0.5
            start = [4.3 + spread * 4.6, -15.8 + sample(2) * 3.7]
            end = [4.7 + spread * 8.7 + sample(3) * 1.5, -10.1 + sample(4) * 4.1]
            radius = 0.16 + pow(sample(5), 2.1) * 0.79
            release = 18.6 + sample(6) * 2.15
            duration = 1.4 + sample(7) * 1.65
            spin = 3.5 + sample(8) * 8.2
            node = SCNNode(geometry: Self.fragment(seed: index, radius: radius))
            node.simdScale = [0.8 + sample(11) * 1.1, 0.54 + sample(12) * 0.68, 0.74 + sample(13) * 0.51]
            update(at: 0, on: land)
        }

        private static func fragment(seed: Int, radius: Float) -> SCNGeometry {
            let sides = 7
            var profile: [SIMD3<Float>] = []
            for ring in 0..<2 {
                for side in 0..<sides {
                    let angle = Float(side) * 2 * .pi / Float(sides) + Float(ring) * 0.32
                    let variation = MountainLandscape.random(seed * 11 + side, ring + 16)
                    let reach = radius * (0.58 + variation * 0.53)
                    let y = radius * (ring == 0 ? 0.22 + variation * 0.5 : -0.31 - variation * 0.35)
                    profile.append([cos(angle) * reach, y, sin(angle) * reach])
                }
            }
            let top = SIMD3<Float>(radius * 0.12, radius * 0.72, -radius * 0.17)
            let bottom = SIMD3<Float>(-radius * 0.16, -radius * 0.66, radius * 0.19)
            var vertices: [SCNVector3] = []
            var normals: [SCNVector3] = []
            var colors: [SIMD4<Float>] = []
            let stoneTone = MountainLandscape.random(seed, 94) * 0.18
            func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
                var normal = simd_normalize(simd_cross(b - a, c - a))
                let outward = simd_dot(normal, a + b + c) > 0
                if !outward { normal = -normal }
                vertices.append(contentsOf: [SCNVector3(a), SCNVector3(outward ? b : c), SCNVector3(outward ? c : b)])
                normals.append(contentsOf: Array(repeating: SCNVector3(normal), count: 3))
                let faceTone = MountainLandscape.random(vertices.count, seed + 112) * 0.10
                let tone = stoneTone + faceTone
                colors.append(contentsOf: Array(repeating: SIMD4(0.30 + tone, 0.27 + tone, 0.22 + tone, 1), count: 3))
            }
            for side in 0..<sides {
                let next = (side + 1) % sides
                triangle(top, profile[side], profile[next])
                triangle(profile[side], profile[side + sides], profile[next])
                triangle(profile[next], profile[side + sides], profile[next + sides])
                triangle(bottom, profile[next + sides], profile[side + sides])
            }
            let mesh = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: normals), MountainLandscape.colorSource(colors)],
                elements: [SCNGeometryElement(indices: vertices.indices.map(Int32.init), primitiveType: .triangles)])
            mesh.firstMaterial = MountainScene.material(NSColor.white)
            return mesh
        }

        func update(at time: Float, on land: MountainLandscape) {
            let t = max(0, min(1, (time - release) / duration))
            let travel = mountainEase(t)
            let p = start + (end - start) * travel
            let hops = abs(sin(t * .pi * 3)) * t * (1 - t) * radius * 3.5
            let height = land.height(p) + radius * (0.25 + 0.22 * travel) + hops
            node.simdPosition = [p.x, height, p.y]
            node.eulerAngles = SCNVector3(t * spin, spin * 0.35 + t * 1.8, t * spin * 0.66)
        }
    }

    private static func makeDust() -> [SCNNode] {
        let texture = radialImage(color: NSColor(srgbRed: 0.83, green: 0.70, blue: 0.55, alpha: 1))
        let surface = material(texture, lit: false)
        surface.isDoubleSided = true
        surface.writesToDepthBuffer = false
        let plane = SCNPlane(width: 2.4, height: 1.9)
        plane.firstMaterial = surface
        return (0..<15).map { _ in
            let node = SCNNode(geometry: plane)
            node.constraints = [SCNBillboardConstraint()]
            node.renderingOrder = 2
            return node
        }
    }

    private static func radialImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 128, height: 128)
        return NSImage(size: size, flipped: false) { rect in
            let gradient = NSGradient(colors: [color.withAlphaComponent(0.70),
                                                color.withAlphaComponent(0.28),
                                                color.withAlphaComponent(0)])!
            gradient.draw(in: rect, relativeCenterPosition: .zero)
            return true
        }
    }

    private static func material(_ contents: Any, lit: Bool = true) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = lit ? .lambert : .constant
        material.diffuse.contents = contents
        return material
    }

    private static func ribbon(_ points: [SIMD3<Float>], width: Float, lift: Float,
                               offset: Float = 0, color: NSColor) -> SCNNode {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        for i in points.indices {
            let tangent = points[min(i + 1, points.count - 1)] - points[max(i - 1, 0)]
            let sideways = simd_normalize(SIMD3<Float>(tangent.z, 0, -tangent.x))
            let center = points[i] + sideways * offset + SIMD3(0, lift, 0)
            vertices.append(SCNVector3(center + sideways * width))
            vertices.append(SCNVector3(center - sideways * width))
            if i > 0 {
                let a = Int32((i - 1) * 2)
                indices += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
            }
        }
        let mesh = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let surface = material(color, lit: false)
        surface.isDoubleSided = true
        mesh.firstMaterial = surface
        return SCNNode(geometry: mesh)
    }
}
#endif
