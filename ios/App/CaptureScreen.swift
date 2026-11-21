import SwiftUI

#if os(iOS)
import CoreLocation
import CoreMotion

@MainActor
private final class PhoneCapture: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var recording = false
    @Published private(set) var requesting = false
    @Published private(set) var message = "Start a foreground recording to log iPhone motion and GPS."
    @Published private(set) var rawSamples = 0
    @Published private(set) var locationSamples = 0
    @Published private(set) var gpsSpeed: Double?
    @Published private(set) var accuracy: Double?
    @Published private(set) var exportURL: URL?

    private let motion = CMMotionManager()
    private let location = CLLocationManager()
    private var writer: CaptureCSV?
    private var totalRaw = 0
    private var startedAt = Date.distantFuture
    private var latestFix = Date.distantPast
    private var generation = 0

    override init() {
        super.init()
        // Core Location delivers delegate calls on the run loop that created the manager.
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = kCLDistanceFilterNone
        location.activityType = .automotiveNavigation
        location.pausesLocationUpdatesAutomatically = false
        exportURL = CaptureCSV.latest()
    }

    func start() {
        guard !recording && !requesting else { return }
        guard motion.isAccelerometerAvailable, motion.isGyroAvailable, motion.isDeviceMotionAvailable else {
            message = "Motion sensors are unavailable here. Use a physical iPhone to capture a drive."
            return
        }
        switch location.authorizationStatus {
        case .notDetermined:
            requesting = true
            message = "Waiting for location permission."
            location.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            openRecording()
        case .denied, .restricted:
            message = "Allow location access in iPhone Settings to record GPS."
        @unknown default:
            message = "Location is unavailable on this device."
        }
    }

    func stop() {
        requesting = false
        guard recording else { return }
        closeRecording(message: "Capture saved. Share the CSV to use it in a dataset review.")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let permission = manager.authorizationStatus
        if recording && (permission == .denied || permission == .restricted) {
            closeRecording(message: "Location access changed. The partial capture was saved.")
        } else if requesting && permission != .notDetermined {
            requesting = false
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let received = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        guard recording else { return }
        for fix in locations {
            guard fix.timestamp > latestFix, fix.timestamp >= startedAt, fix.timestamp <= received,
                  CLLocationCoordinate2DIsValid(fix.coordinate), fix.horizontalAccuracy >= 0 else { continue }
            latestFix = fix.timestamp
            gpsSpeed = fix.speed >= 0 ? fix.speed : nil
            accuracy = fix.horizontalAccuracy
            locationSamples += 1
            append(.init(kind: "location", receive: (uptime, received.timeIntervalSince1970), sampleBoot: nil,
                         sampleUnix: fix.timestamp.timeIntervalSince1970, values: [], location: [
                             fix.coordinate.latitude, fix.coordinate.longitude, fix.horizontalAccuracy,
                             gpsSpeed, fix.speedAccuracy >= 0 ? fix.speedAccuracy : nil,
                             fix.course >= 0 ? fix.course : nil, fix.courseAccuracy >= 0 ? fix.courseAccuracy : nil,
                             fix.sourceInformation.map { $0.isSimulatedBySoftware ? 1 : 0 },
                             fix.sourceInformation.map { $0.isProducedByAccessory ? 1 : 0 }
                         ]))
            if !recording { break }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard recording else { return }
        let nsError = error as NSError
        if nsError.domain == kCLErrorDomain && nsError.code == CLError.locationUnknown.rawValue {
            message = "GPS fix unavailable. Motion recording continues."
        } else {
            closeRecording(message: "GPS recording ended. The partial capture was saved.")
        }
    }

    private func openRecording() {
        let frame: CMAttitudeReferenceFrame = CMMotionManager.availableAttitudeReferenceFrames()
            .contains(.xArbitraryCorrectedZVertical) ? .xArbitraryCorrectedZVertical : .xArbitraryZVertical
        do {
            writer = try CaptureCSV()
            let now = Date()
            try writer?.append(.init(kind: frame == .xArbitraryCorrectedZVertical
                                     ? "start_corrected_z_vertical" : "start_z_vertical",
                                     receive: (ProcessInfo.processInfo.systemUptime, now.timeIntervalSince1970),
                                     sampleBoot: nil, sampleUnix: nil, values: []))
            startedAt = now
        } catch {
            writer = nil
            message = "The recording file could not be opened."
            return
        }
        totalRaw = 0
        rawSamples = 0
        locationSamples = 0
        gpsSpeed = nil
        accuracy = nil
        latestFix = .distantPast
        recording = true
        generation += 1
        let current = generation
        message = location.accuracyAuthorization == .fullAccuracy ? "Recording in the foreground."
            : "Recording with reduced location accuracy."
        motion.accelerometerUpdateInterval = 0.02
        motion.gyroUpdateInterval = 0.02
        motion.deviceMotionUpdateInterval = 0.02
        motion.startAccelerometerUpdates(to: .main) { [weak self] sample, error in
            guard let self, self.generation == current, self.recording else { return }
            if let error { self.failMotion(error); return }
            guard let sample else { return }
            let a = sample.acceleration
            self.addMotion("raw_accelerometer", sample.timestamp, [a.x * 9.80665, a.y * 9.80665, a.z * 9.80665])
        }
        motion.startGyroUpdates(to: .main) { [weak self] sample, error in
            guard let self, self.generation == current, self.recording else { return }
            if let error { self.failMotion(error); return }
            guard let sample else { return }
            let g = sample.rotationRate
            self.addMotion("raw_gyroscope", sample.timestamp, [nil, nil, nil, g.x, g.y, g.z])
        }
        motion.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] sample, error in
            guard let self, self.generation == current, self.recording else { return }
            if let error { self.failMotion(error); return }
            guard let sample else { return }
            let a = sample.userAcceleration
            let g = sample.rotationRate
            let gravity = sample.gravity
            self.addMotion("device_motion", sample.timestamp,
                           [a.x * 9.80665, a.y * 9.80665, a.z * 9.80665, g.x, g.y, g.z,
                            gravity.x, gravity.y, gravity.z])
        }
        location.startUpdatingLocation()
    }

    private func addMotion(_ kind: String, _ time: Double, _ values: [Double?]) {
        guard time.isFinite, time >= 0, values.allSatisfy({ $0?.isFinite ?? true }) else { return }
        if kind != "device_motion" {
            totalRaw += 1
            if totalRaw.isMultiple(of: 20) { rawSamples = totalRaw }
        }
        append(.init(kind: kind, receive: (ProcessInfo.processInfo.systemUptime, Date().timeIntervalSince1970),
                     sampleBoot: time, sampleUnix: nil, values: values))
    }

    private func append(_ sample: CaptureCSV.Sample) {
        do { try writer?.append(sample) } catch {
            closeRecording(message: "Storage interrupted capture. The file may be incomplete.")
        }
    }

    private func failMotion(_ error: Error) {
        closeRecording(message: "Motion recording ended. \(error.localizedDescription)")
    }

    private func closeRecording(message newMessage: String) {
        recording = false
        generation += 1
        motion.stopAccelerometerUpdates()
        motion.stopGyroUpdates()
        motion.stopDeviceMotionUpdates()
        location.stopUpdatingLocation()
        rawSamples = totalRaw
        message = newMessage
        if let writer {
            do {
                try writer.close()
                exportURL = writer.url
            } catch {
                message = "The recording could not be finalized. Storage may be full."
            }
        }
        writer = nil
    }
}

@MainActor
final class CaptureCSV {
    struct Sample {
        let kind: String
        let receive: (uptime: Double, unix: Double)
        let sampleBoot: Double?
        let sampleUnix: Double?
        let values: [Double?]
        var location: [Double?] = []
    }

    let url: URL
    private let handle: FileHandle
    private var buffer = Data()

    init() throws {
        let directory = try Self.directory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "Driftlock-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(8)).csv"
        url = directory.appendingPathComponent(name)
        try Data((CaptureFormat.columns.joined(separator: ",") + "\n").utf8).write(to: url, options: [.withoutOverwriting])
        handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    static func latest() -> URL? { files().first }

    static func files() -> [URL] {
        guard let directory = try? directory(),
              let files = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                  options: [.skipsHiddenFiles]
              )
        else { return [] }
        return files.filter {
            $0.pathExtension == "csv" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func directory() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("DriftlockCaptures", isDirectory: true)
    }

    func append(_ sample: Sample) throws {
        let motion = sample.values + Array(repeating: nil, count: 9 - sample.values.count)
        let location = sample.location + Array(repeating: nil, count: 9 - sample.location.count)
        let values = [sample.sampleBoot, sample.sampleUnix, sample.receive.uptime, sample.receive.unix] + motion + location
        let row = values.map { value in value.map { $0.isFinite ? String($0) : "" } ?? "" }
        buffer.append(contentsOf: ([CaptureFormat.version, sample.kind] + row).joined(separator: ",").utf8)
        buffer.append(10)
        if buffer.count >= 24_576 {
            try flush()
        }
    }

    private func flush() throws {
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            buffer.removeAll(keepingCapacity: true)
        }
    }

    func close() throws {
        do {
            try flush()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }
}
#endif

struct CaptureScreen: View {
    let openReplay: (URL) -> Void
    let loading: Bool
    #if os(iOS)
    @StateObject private var capture = PhoneCapture()
    @Environment(\.scenePhase) private var scenePhase
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Record a drive").font(.system(size: 31, weight: .bold)).tracking(-1)
                        .accessibilityAddTraits(.isHeader)
                    Text("Collect motion and location samples for Driftlock’s next dataset.")
                        .font(.subheadline).foregroundStyle(DriftStyle.muted)
                }
                #if os(iOS)
                HStack(alignment: .top, spacing: 10) {
                    captureMetric("Raw IMU samples", String(capture.rawSamples), "waveform")
                    captureMetric("Location fixes", String(capture.locationSamples), "location")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label(capture.message, systemImage: capture.recording ? "record.circle" : "iphone")
                        .font(.subheadline)
                        .foregroundStyle(capture.recording ? DriftStyle.mint : DriftStyle.ink)
                    if let speed = capture.gpsSpeed, let accuracy = capture.accuracy {
                        Text(String(format: "GPS %.1f km/h  ·  horizontal accuracy %.0f m", speed * 3.6, accuracy))
                            .font(.caption.monospacedDigit()).foregroundStyle(DriftStyle.muted)
                    }
                    Button {
                        capture.recording ? capture.stop() : capture.start()
                    } label: {
                        Label(capture.recording ? "Stop and save" : "Start capture",
                              systemImage: capture.recording ? "stop.fill" : "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DriftActionStyle(primary: true))
                    .disabled(capture.requesting)
                    if let file = capture.exportURL, !capture.recording {
                        Button {
                            openReplay(file)
                        } label: {
                            Label(loading ? "Preparing replay…" : "Replay recorded drive", systemImage: "play.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DriftActionStyle())
                        .disabled(loading)
                        ShareLink(item: file) {
                            Label("Share recorded CSV", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DriftActionStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).driftPanel()
                Text("Mount the phone before the drive and keep this screen open. Recordings are stored on the device.")
                    .font(.caption).foregroundStyle(DriftStyle.muted)
                #else
                ContentUnavailableView("Use an iPhone for capture", systemImage: "iphone",
                                       description: Text("The recorded-drive replay runs offline on this Mac."))
                    .driftPanel()
                #endif
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        #if os(iOS)
        .onDisappear { capture.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { capture.stop() } }
        #endif
    }

    #if os(iOS)
    private func captureMetric(_ name: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(DriftStyle.mint)
            Text(value).font(.system(.title2, design: .monospaced).weight(.semibold))
                .contentTransition(.numericText())
            Text(name).font(.caption).foregroundStyle(DriftStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .driftPanel()
    }
    #endif
}
