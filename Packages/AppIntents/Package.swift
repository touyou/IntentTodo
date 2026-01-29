// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppIntents",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AppIntents",
            targets: ["TodoAppIntents"]
        )
    ],
    dependencies: [
        .package(path: "../Repository")
    ],
    targets: [
        .target(
            name: "TodoAppIntents",
            dependencies: ["Repository"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AppIntentsTests",
            dependencies: ["TodoAppIntents"]
        )
    ]
)
