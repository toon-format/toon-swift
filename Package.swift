// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ToonFormat",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
        .watchOS("6.0"),
        .tvOS("13.0"),
        .visionOS("1.0"),
    ],
    products: [
        .library(
            name: "ToonFormat",
            targets: ["ToonFormat"]
        ),
        .executable(
            name: "toon",
            targets: ["toon"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "ToonFormat"
        ),
        .executableTarget(
            name: "toon",
            dependencies: [
                "ToonFormat",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ToonFormatTests",
            dependencies: ["ToonFormat"]
        ),
    ]
)
