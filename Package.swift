// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BetterThanDato",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DatoCore"),
        .executableTarget(
            name: "BetterThanDato",
            dependencies: ["DatoCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "DatoCoreTests", dependencies: ["DatoCore"]),
    ]
)
