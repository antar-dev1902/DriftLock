import AVFAudio
import Flutter
import SwiftUI
import UIKit

@MainActor
final class DriftlockBridge {
    private var channel: FlutterMethodChannel?
    private var audioPlayer: AVAudioPlayer?
    private var recording = false

    func install(_ messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "driftlock/ios", binaryMessenger: messenger)
        self.channel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result)
        }
    }

    private var presenter: UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
        var top = window?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        switch call.method {
        case "openRecorder":
            guard let presenter else { result(failure("The recorder could not be opened.")); return }
            let screen = RecorderSheet { [weak self] url in
                guard let self else { result(nil); return }
                if let url { self.render(url, method: "loadCapture", finish: result) }
                else { result(nil) }
            }
            let host = UIHostingController(rootView: screen)
            host.modalPresentationStyle = .fullScreen
            presenter.present(host, animated: true)
        case "listCaptures":
            result(CaptureCSV.files().map { url in
                [
                    "id": url.lastPathComponent,
                    "date": ISO8601DateFormatter().string(from:
                        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast),
                ]
            })
        case "loadCapture", "benchmark", "shareCapture":
            guard let name = call.arguments as? String,
                  let url = CaptureCSV.files().first(where: { $0.lastPathComponent == name })
            else { result(failure("The local recording is unavailable.")); return }
            if call.method == "shareCapture" { share(url, result) }
            else { render(url, method: call.method, finish: result) }
        case "shareText":
            guard let args = call.arguments as? [String: String], let filename = args["filename"],
                  ["json", "csv"].contains(URL(fileURLWithPath: filename).pathExtension),
                  filename == URL(fileURLWithPath: filename).lastPathComponent,
                  let text = args["text"] else { result(failure("Invalid export.")); return }
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
                let url = directory.appendingPathComponent(filename)
                try Data(text.utf8).write(to: url)
                share(url, result)
            } catch { result(failure(error.localizedDescription)) }
        case "recordVoice":
            guard !recording else { result(failure("A voice recording is already in progress.")); return }
            recording = true
            Task { await record(result) }
        case "playVoice":
            guard let data = call.arguments as? FlutterStandardTypedData else {
                result(failure("The audio was unavailable.")); return
            }
            do {
                audioPlayer = try AVAudioPlayer(data: data.data)
                guard audioPlayer?.play() == true else { result(failure("Could not play audio.")); return }
                result(nil)
            } catch { result(failure(error.localizedDescription)) }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func render(_ url: URL, method: String, finish: @escaping FlutterResult) {
        Task {
            do {
                let text = try await Task.detached(priority: .userInitiated) {
                    let drive = try RecordedDrive.loadCapture(from: url)
                    let replay = HackathonReplay()
                    let data = try method == "benchmark" ? replay.benchmark(for: drive) : replay.playback(for: drive)
                    return String(decoding: data, as: UTF8.self)
                }.value
                if method == "benchmark" { finish(text) }
                else { finish(["id": url.lastPathComponent, "playback": text]) }
            } catch { finish(failure(error.localizedDescription)) }
        }
    }

    private func share(_ url: URL, _ finish: @escaping FlutterResult) {
        guard let presenter else { finish(failure("Sharing is unavailable.")); return }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = presenter.view.bounds
        presenter.present(sheet, animated: true)
        finish(nil)
    }

    private func record(_ finish: @escaping FlutterResult) async {
        defer { recording = false }
        guard await AVAudioApplication.requestRecordPermission() else {
            finish(failure("Microphone access was declined.")); return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            defer { try? session.setActive(false, options: [.notifyOthersOnDeactivation]) }
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
            ])
            guard recorder.record(forDuration: 6) else {
                finish(failure("The microphone could not start.")); return
            }
            try await Task.sleep(for: .seconds(6))
            recorder.stop()
            let data = try Data(contentsOf: url)
            guard data.count > 44, UIApplication.shared.applicationState == .active else {
                finish(failure("The recording ended before the clip was ready.")); return
            }
            finish(FlutterStandardTypedData(bytes: data))
        } catch { finish(failure(error.localizedDescription)) }
    }

    private func failure(_ message: String) -> FlutterError {
        FlutterError(code: "driftlock_ios", message: message, details: nil)
    }
}

private struct RecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let finish: (URL?) -> Void

    var body: some View {
        NavigationStack {
            CaptureScreen(openReplay: close, loading: false)
                .background(DriftStyle.background.ignoresSafeArea())
                .navigationTitle("DriftLock Recorder")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { close(nil) }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }

    private func close(_ url: URL?) {
        dismiss()
        finish(url)
    }
}
