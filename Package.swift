// swift-tools-version:5.2
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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "0.1.0"),
        .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .revision("5abb16c6ea0657a23bca2660c49ed65465e7cc7a")),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", from: "0.1.3"),
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
