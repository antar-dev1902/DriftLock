// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DriftlockReplay",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "DriftCore", targets: ["DriftCore"]),
        .executable(name: "driftlock-replay-audit", targets: ["ReplayAudit"]),
        .executable(name: "driftlock-export-playback", targets: ["ReplayExport"])
    ],
    targets: [
        .target(name: "DriftCore", path: "DriftCore"),
        .executableTarget(name: "ReplayAudit", dependencies: ["DriftCore"], path: "Tools/ReplayAudit"),
        .executableTarget(name: "ReplayExport", dependencies: ["DriftCore"], path: "Tools/ReplayExport"),
        .testTarget(name: "DriftCoreTests", dependencies: ["DriftCore"], path: "Tests/DriftCoreTests")
    ]
)
