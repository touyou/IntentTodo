// swift-tools-version: 6.0
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
        ),
    ],
    dependencies: [
        .package(path: "../TodoAppIntents"),
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "UI",
            dependencies: [
                .product(name: "TodoAppIntents", package: "TodoAppIntents"),
                .product(name: "Domain", package: "Domain"),
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
