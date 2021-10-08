// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-create-xcframework",

    // TODO: Add Linux / Windows support
    platforms: [
        .macOS(.v10_15),
    ],

    products: [
        .executable(name: "swift-create-xcframework", targets: [ "CreateXCFramework" ]),
    ],

    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("0.4.4")),
        .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .branch("release/5.5")),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", .exact("0.2.3")),
    ],

    targets: [
        .target(name: "CreateXCFramework", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftPM-auto", package: "SwiftPM"),
            .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ]),
        .testTarget(name: "CreateXCFrameworkTests", dependencies: [ "CreateXCFramework" ]),
    ],

    swiftLanguageVersions: [
        .v5
    ]
)
