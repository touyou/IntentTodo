// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "LiveActivity",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(
            name: "LiveActivity",
            targets: ["LiveActivity"]
        ),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../TodoAppIntents"),
    ],
    targets: [
        .target(
            name: "LiveActivity",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "TodoAppIntents", package: "TodoAppIntents"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
