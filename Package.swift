// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IntentTodoPackages",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "IntentTodoPackages", targets: ["IntentTodoPackages"])
    ],
    dependencies: [
        .package(path: "Packages/UI")
    ],
    targets: [
        .target(
            name: "IntentTodoPackages",
            dependencies: [
                .product(name: "UI", package: "UI")
            ]
        )
    ]
)
