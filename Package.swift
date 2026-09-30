// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BetterThanDato",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Auto-updates (appcast + EdDSA-signed zips on GitHub Releases).
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        .target(name: "DatoCore"),
        .executableTarget(
            name: "BetterThanDato",
            dependencies: ["DatoCore", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // Sparkle.framework is embedded in Contents/Frameworks by scripts/build-app.sh.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "DatoCoreTests", dependencies: ["DatoCore"]),
    ]
)
