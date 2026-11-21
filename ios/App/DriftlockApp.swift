import SwiftUI

struct DriftMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(DriftStyle.mint)
            Image(systemName: "location.north.line")
                .font(.system(size: 17, weight: .semibold))
                .rotationEffect(.degrees(28))
                .foregroundStyle(DriftStyle.background)
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}

enum DriftPage: String, CaseIterable {
    case replay = "Replay", capture = "Capture"

    var symbol: String {
        switch self {
        case .replay: "point.topleft.down.to.point.bottomright.curvepath"
        case .capture: "waveform"
        }
    }
}

@main
struct DriftlockApp: App {
    var body: some Scene {
        WindowGroup {
            DriftlockRoot()
                .preferredColorScheme(.dark)
        }
        #if os(macOS)
        .defaultSize(width: 530, height: 900)
        #endif
    }
}

@MainActor
private final class DriftRootState: ObservableObject {
    @Published var page = DriftPage.replay
    @Published var evidence = false
    @Published var captureError: String?
    @Published private(set) var loadingCapture = false
    @Published private(set) var capture: RecordedDrive?

    let sample: Result<RecordedDrive, Error> = Result {
        guard let url = Bundle.main.url(forResource: "AustinReplay", withExtension: "json") else {
            throw ReplayError.invalidRecording
        }
        return try RecordedDrive.load(from: url)
    }
    var recording: Result<RecordedDrive, Error> {
        if let capture { return .success(capture) }
        return sample
    }

    func openCapture(_ url: URL) {
        guard !loadingCapture else { return }
        loadingCapture = true
        Task {
            defer { loadingCapture = false }
            do {
                capture = try await Task.detached(priority: .userInitiated) {
                    try RecordedDrive.loadCapture(from: url)
                }.value
                page = .replay
            } catch {
                captureError = error.localizedDescription
            }
        }
    }

    func showPublicDrive() {
        capture = nil
        page = .replay
    }
}

private struct DriftlockRoot: View {
    @StateObject private var state = DriftRootState()

    var body: some View {
        VStack(spacing: 0) {
            header
            switch state.page {
            case .replay:
                switch state.recording {
                case .success(let drive):
                    ReplayScreen(drive: drive) { state.evidence = true }
                        .id(state.capture != nil)
                case .failure(let error):
                    ContentUnavailableView("Drive unavailable", systemImage: "map",
                                           description: Text(error.localizedDescription))
                }
            case .capture:
                CaptureScreen(openReplay: state.openCapture, loading: state.loadingCapture)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DriftStyle.background.ignoresSafeArea())
        .foregroundStyle(DriftStyle.ink)
        .tint(DriftStyle.mint)
        .sheet(isPresented: $state.evidence) {
            if case .success(let drive) = state.recording {
                EvidenceSheet(drive: drive)
            }
        }
        .alert("Can’t replay this drive", isPresented: Binding(
            get: { state.captureError != nil },
            set: { if !$0 { state.captureError = nil } }
        )) {
            Button("OK", role: .cancel) { state.captureError = nil }
        } message: {
            Text(state.captureError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 15) {
            HStack(spacing: 10) {
                DriftMark()
                Text("DRIFTLOCK").font(.system(.headline, design: .monospaced).weight(.bold))
                    .tracking(2.8)
                    .accessibilityLabel("Driftlock")
                Spacer()
                if state.page == .replay, state.capture != nil {
                    Button("Austin sample", action: state.showPublicDrive)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 5)
                }
                if state.page == .replay, case .success = state.recording {
                    Button {
                        state.evidence = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 19, weight: .medium))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(DriftStyle.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Replay evidence")
                }
            }
            HStack(spacing: 4) {
                ForEach(DriftPage.allCases, id: \.self) { item in
                    Button {
                        state.page = item
                    } label: {
                        Label(item.rawValue, systemImage: item.symbol)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 39)
                            .background(state.page == item ? DriftStyle.raised : .clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(state.page == item ? DriftStyle.mint : DriftStyle.muted)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(state.page == item ? [.isSelected] : [])
                }
            }
            .padding(4)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(DriftStyle.border.opacity(0.65)) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: 940)
    }
}
