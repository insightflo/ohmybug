// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OhMyBugApp",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../OhMyBugCore"),
    ],
    targets: [
        .executableTarget(
            name: "OhMyBugApp",
            dependencies: [
                .product(name: "OhMyBugCore", package: "OhMyBugCore"),
            ],
            path: "OhMyBugApp",
            resources: [
                .copy("Resources/AppIcon.icns")
            ]
        ),
    ]
)
