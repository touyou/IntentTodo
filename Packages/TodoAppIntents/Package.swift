// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TodoAppIntents",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "TodoAppIntents",
            targets: ["TodoAppIntents"]
        ),
    ],
    dependencies: [
        .package(path: "../Repository"),
    ],
    targets: [
        .target(
            name: "TodoAppIntents",
            dependencies: [
                .product(name: "Repository", package: "Repository"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TodoAppIntentsTests",
            dependencies: ["TodoAppIntents"]
        ),
    ]
)
