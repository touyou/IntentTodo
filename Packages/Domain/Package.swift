// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Domain",
            targets: ["Domain"]
        ),
    ],
    targets: [
        .target(
            name: "Domain",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
    ]
)
