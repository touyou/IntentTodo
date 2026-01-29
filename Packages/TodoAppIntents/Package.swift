// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TodoAppIntents",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
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
