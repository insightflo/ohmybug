// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OhMyBugCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "OhMyBugCore",
            targets: ["OhMyBugCore"]
        ),
        .executable(
            name: "ohmybug",
            targets: ["OhMyBugCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "OhMyBugCore",
            dependencies: []
        ),
        .executableTarget(
            name: "OhMyBugCLI",
            dependencies: [
                "OhMyBugCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "OhMyBugCoreTests",
            dependencies: ["OhMyBugCore"]
        ),
    ]
)
