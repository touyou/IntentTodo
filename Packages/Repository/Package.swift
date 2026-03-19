// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Repository",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Repository",
            targets: ["Repository"]
        ),
    ],
    dependencies: [
        .package(path: "../Domain"),
    ],
    targets: [
        .target(
            name: "Repository",
            dependencies: [
                .product(name: "Domain", package: "Domain"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "RepositoryTests",
            dependencies: ["Repository"]
        ),
    ]
)
