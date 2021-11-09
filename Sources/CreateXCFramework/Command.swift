//
//  Command.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import ArgumentParser
import Foundation
import PackageLoading
import PackageModel
import TSCBasic
import Workspace
import Xcodeproj

struct Command: ParsableCommand {

    // MARK: - Configuration

    static var configuration = CommandConfiguration (
        abstract: "Creates an XCFramework out of a Swift Package using xcodebuild",
        discussion:
            """
            Note that Swift Binary Frameworks (XCFramework) support is only available in Swift 5.1
            or newer, and so it is only supported by recent versions of Xcode and the *OS SDKs. Likewise,
            only Apple pplatforms are supported.

            Supported platforms: \(TargetPlatform.allCases.map({ $0.rawValue }).joined(separator: ", "))
            """,
        version: "1.4.0"
    )


    // MARK: - Arguments

    @OptionGroup()
    var options: Options


    // MARK: - Execution

    // swiftlint:disable:next function_body_length
    func run() throws {

        // load all/validate of the package info
        let package = try PackageInfo(options: self.options)

        // validate that package to make sure we can generate it
        let validation = package.validationErrors()
        if validation.isEmpty == false {
            for error in validation {
                print((error.isFatal ? "Error:" : "Warning:"), error.errorDescription!)
            }
            if validation.contains(where: { $0.isFatal }) {
                Darwin.exit(1)
            }
        }

        // using the legacy generation
        if self.options.legacy {
            try self.runLegacy(package: package)
            return
        }

        // printing packages?
        if self.options.listProducts {
            package.printAllProducts()
            Darwin.exit(0)
        }

        // validate product names
        let productNames = try package.validProductNames()

        // get package and SDK info
        let platforms = try package.supportedPlatforms()
        let sdks = platforms.flatMap { $0.sdks }

        // start building
        let builder = XcodeBuilder(package: package, options: self.options)

        let frameworks = try self.build(products: productNames, sdks: sdks, builder: builder)
        let xcframeworks = try self.createXCFrameworks(frameworks: frameworks, builder: builder)

        if self.options.zip {
            let zipped = try self.zip(xcframeworks: xcframeworks, package: package)

            if self.options.githubAction {
                try self.githubNotify(zippedXCFrameworks: zipped)
            }
        }
    }

    func runLegacy(package: PackageInfo) throws {

        // generate the Xcode project file
        let generator = ProjectGenerator(package: package)

        // get what we're building
        try generator.writeDistributionXcconfig()
        let project = try generator.generate()

        // printing packages?
        if self.options.listProducts {
            package.printAllLegacyProducts(project: project)
            Darwin.exit(0)
        }

        // get valid packages and their SDKs
        let productNames = try package.validLegacyProductNames(project: project)
        let sdks = try package.supportedPlatforms()
            .flatMap { $0.sdks }

        // we've applied the xcconfig to everything, but some dependencies (*cough* swift-nio)
        // have build errors, so we remove it from targets we're not building
        if self.options.stackEvolution == false {
            try project.enableDistribution(targets: productNames, xcconfig: AbsolutePath(package.distributionBuildXcconfig.path).relative(to: AbsolutePath(package.rootDirectory.path)))
        }

        // save the project
        try project.save(to: generator.projectPath)

        // start building
        let builder = XcodeBuilder(projectPath: generator.projectPath, package: package, options: self.options)

        if self.options.clean {
            try builder.clean()
        }

        let frameworks = try self.build(products: productNames, sdks: sdks, builder: builder)
        let xcframeworks = try self.createXCFrameworks(frameworks: frameworks, builder: builder)

        if self.options.zip {
            let zipped = try self.zip(xcframeworks: xcframeworks, package: package)

            if self.options.githubAction {
                try self.githubNotify(zippedXCFrameworks: zipped)
            }
        }
    }

    private func build (products: [String], sdks: [TargetPlatform.SDK], builder: XcodeBuilder) throws -> [String: [BuildResult]] {
        var frameworks: [String: [BuildResult]] = [:]

        for sdk in sdks {
            try builder.build(targets: products, sdk: sdk)
                .forEach { pair in
                    if frameworks[pair.key] == nil {
                        frameworks[pair.key] = []
                    }
                    frameworks[pair.key]?.append(pair.value)
                }
        }

        return frameworks
    }

    struct XCFramework {
        let target: String
        let xcframework: Foundation.URL
    }

    private func createXCFrameworks (frameworks: [String: [BuildResult]], builder: XcodeBuilder) throws -> [XCFramework] {
        return try frameworks
            .map { pair in
                XCFramework(
                    target: pair.key,
                    xcframework: try builder.merge(target: pair.key, buildResults: pair.value)
                )
            }
    }

    private func zip (xcframeworks: [XCFramework], package: PackageInfo) throws -> [Foundation.URL] {
        let zipper = Zipper(package: package)
        let zipped = try xcframeworks
            .flatMap { pair -> [Foundation.URL] in
                let zip = try zipper.zip(target: pair.target, version: self.options.zipVersion, file: pair.xcframework)
                let checksum = try zipper.checksum(file: zip)
                try zipper.clean(file: pair.xcframework)

                return [ zip, checksum ]
            }
        return zipped
    }

    private func githubNotify (zippedXCFrameworks: [Foundation.URL]) throws {
        let zips = zippedXCFrameworks.map({ $0.path }).joined(separator: "\n")
        let data = Data(zips.utf8)
        let url = Foundation.URL(fileURLWithPath: self.options.buildPath).appendingPathComponent("xcframework-zipfile.url")
        try data.write(to: url)
    }

}


// MARK: - Errors

private enum Error: Swift.Error, LocalizedError {
    case noProducts

    var errorDescription: String? {
        switch self {
        case .noProducts:           return ""
        }
    }
}
