// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "TaskGroupError",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TaskGroupError",
            targets: ["TaskGroupError"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.49.0"),
         .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
    ],
    targets: [
        .target(
            name: "TaskGroupError",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]),
        .testTarget(
            name: "TaskGroupErrorTests",
            dependencies: ["TaskGroupError"]),
    ]
)
