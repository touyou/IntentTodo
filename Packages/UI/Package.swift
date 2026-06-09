// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "UI",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(
            name: "UI",
            targets: ["UI"]
        ),
    ],
    dependencies: [
        .package(path: "../TodoAppIntents"),
        .package(path: "../Domain"),
        .package(path: "../LiveActivity"),
    ],
    targets: [
        .target(
            name: "UI",
            dependencies: [
                .product(name: "TodoAppIntents", package: "TodoAppIntents"),
                .product(name: "Domain", package: "Domain"),
                .product(name: "LiveActivity", package: "LiveActivity"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "UITests",
            dependencies: ["UI", "TodoAppIntents"]
        ),
    ]
)
