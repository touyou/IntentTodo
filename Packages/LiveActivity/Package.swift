// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiveActivity",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
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
