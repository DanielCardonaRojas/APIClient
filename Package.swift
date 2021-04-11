// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APIClient",
    platforms: [
        .iOS(SupportedPlatform.IOSVersion.v13),
        .macOS(SupportedPlatform.MacOSVersion.v10_14)
    ],
    products: [
        .library(
            name: "APIClient",
            targets: ["APIClient"])
    ],
    targets: [
        .target(
            name: "APIClient",
            dependencies: ["Utils"],
            path: "./APIClient"
        ),
        .target(name: "Utils", path: "Utils"),
        .testTarget(
            name: "APIClientTests",
            dependencies: ["APIClient", "Utils"],
            path: "./APIClientTests",
            resources: [
                .copy("./fixtures/posts.json"),
                .copy("./fixtures/post_detail.json"),
            ]
        )
    ]
)
