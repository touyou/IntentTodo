// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "WidgetUI",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(
            name: "WidgetUI",
            targets: ["WidgetUI"]
        )
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../TodoAppIntents")
    ],
    targets: [
        .target(
            name: "WidgetUI",
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
