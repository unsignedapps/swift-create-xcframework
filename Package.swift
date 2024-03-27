// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let dependencies: [Package.Dependency]
let versionedTargets: [Target]
let versionedDependencies: [Target.Dependency]

#if swift(>=5.9)
dependencies = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("1.2.3")),
    .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .branch("release/5.9")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch("release/5.9")),
]
versionedTargets = [
    .target(
        name: "Xcodeproj",
        dependencies: [
            .product(name: "SwiftPM-auto", package: "SwiftPM"),
            .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        ]
    )
]
versionedDependencies = ["Xcodeproj"]
#elseif swift(>=5.7)
dependencies = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("1.0.3")),
    .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .branch("release/5.7")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch("release/5.7")),
]
versionedTargets = []
versionedDependencies = []
#elseif swift(>=5.6)
dependencies = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("1.0.3")),
    .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .branch("release/5.6")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .exact("0.2.5"))
]
versionedTargets = []
versionedDependencies = []
#elseif swift(>=5.5)
dependencies = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("0.4.4")),
    .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .branch("release/5.5")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .exact("0.2.3"))
]
versionedTargets = []
versionedDependencies = []
#else
dependencies = [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .exact("0.3.2")),
    .package(name: "SwiftPM", url: "https://github.com/apple/swift-package-manager.git", .revision("swift-5.3.3-RELEASE")),
    .package(url: "https://github.com/apple/swift-tools-support-core.git", .exact("0.1.12"))
]
versionedTargets = []
versionedDependencies = []
#endif

let platforms: [SupportedPlatform]
#if swift(>=5.6)
platforms = [
    .macOS(.v11),
]
#else
platforms = [
    .macOS(.v10_15),
]
#endif

let package = Package(
    name: "swift-create-xcframework",

    // TODO: Add Linux / Windows support
    platforms: platforms,

    products: [
        .executable(name: "swift-create-xcframework", targets: [ "CreateXCFramework" ]),
    ],

    dependencies: dependencies,

    targets: versionedTargets + [
        .target(name: "CreateXCFramework", dependencies: versionedDependencies + [
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
