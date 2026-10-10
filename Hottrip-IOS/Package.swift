// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HottripUI",
    defaultLocalization: "ru",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HottripUI", targets: ["HottripUI"]),
        .executable(name: "HottripSnapshots", targets: ["HottripSnapshots"]),
    ],
    targets: [
        .target(
            name: "HottripUI",
            resources: [.copy("Resources/Images")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "HottripSnapshots",
            dependencies: ["HottripUI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
