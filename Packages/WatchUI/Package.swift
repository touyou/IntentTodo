// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "WatchUI",
    platforms: [
        .watchOS(.v27)
    ],
    products: [
        .library(
            name: "WatchUI",
            targets: ["WatchUI"]
        )
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../TodoAppIntents")
    ],
    targets: [
        .target(
            name: "WatchUI",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "TodoAppIntents", package: "TodoAppIntents")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
