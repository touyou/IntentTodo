// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IntentTodo",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Repository", targets: ["Repository"]),
        .library(name: "TodoAppIntents", targets: ["TodoAppIntents"]),
        .library(name: "UI", targets: ["UI"])
    ],
    targets: [
        // MARK: - Domain
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

        // MARK: - Repository
        .target(
            name: "Repository",
            dependencies: ["Domain"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "RepositoryTests",
            dependencies: ["Repository"]
        ),

        // MARK: - AppIntents
        .target(
            name: "TodoAppIntents",
            dependencies: ["Repository"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AppIntentsTests",
            dependencies: ["TodoAppIntents"]
        ),

        // MARK: - UI
        .target(
            name: "UI",
            dependencies: ["TodoAppIntents"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "UITests",
            dependencies: ["UI", "TodoAppIntents"]
        )
    ]
)
