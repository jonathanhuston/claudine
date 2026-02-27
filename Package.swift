// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Claudine",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "claudine", targets: ["claudine"]),
        .library(name: "ClaudineCore", targets: ["ClaudineCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/objecthub/swift-commandlinekit.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "claudine",
            dependencies: [
                "ClaudineCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "ClaudineCore",
            dependencies: [
                .product(name: "CommandLineKit", package: "swift-commandlinekit"),
            ]
        ),
        .testTarget(
            name: "ClaudineCoreTests",
            dependencies: ["ClaudineCore"]
        ),
    ]
)
