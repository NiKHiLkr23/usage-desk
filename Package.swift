// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResetDesk",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ResetDesk", targets: ["ResetDesk"])],
    targets: [
        .target(name: "ResetDeskCore"),
        .executableTarget(name: "ResetDesk", dependencies: ["ResetDeskCore"], resources: [.process("Resources")]),
        .testTarget(name: "ResetDeskPresentationTests", dependencies: ["ResetDesk"]),
        .testTarget(name: "ResetDeskCoreTests", dependencies: ["ResetDeskCore"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v5]
)
