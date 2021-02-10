// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "APIClient",
    products: [
        .library(
            name: "APIClient",
            targets: ["APIClient"])
    ],
    targets: [
        .target(
            name: "APIClient",
            dependencies: [],
			path: "APIClient"),
        .testTarget(
        name: "APIClientTests", dependencies: ["APIClient"],
        path: "./APIClientTests")
    ]
)
