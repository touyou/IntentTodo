// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "TodoAppIntents",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27)
    ],
    products: [
        .library(
            name: "TodoAppIntents",
            targets: ["TodoAppIntents"]
        )
    ],
    dependencies: [
        .package(path: "../Domain"),
        .package(path: "../Repository")
    ],
    targets: [
        .target(
            name: "TodoAppIntents",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
                .product(name: "Repository", package: "Repository")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TodoAppIntentsTests",
            dependencies: ["TodoAppIntents"]
        )
    ]
)
