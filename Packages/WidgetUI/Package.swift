// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WidgetUI",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "WidgetUI",
            targets: ["WidgetUI"]
        ),
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../TodoAppIntents"),
    ],
    targets: [
        .target(
            name: "WidgetUI",
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
