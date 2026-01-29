// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UI",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "UI",
            targets: ["UI"]
        )
    ],
    dependencies: [
        .package(path: "../AppIntents")
    ],
    targets: [
        .target(
            name: "UI",
            dependencies: [
                .product(name: "AppIntents", package: "AppIntents")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "UITests",
            dependencies: ["UI"]
        )
    ]
)
