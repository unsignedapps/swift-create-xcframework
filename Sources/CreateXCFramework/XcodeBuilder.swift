//
//  XcodeBuilder.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import Build
import Foundation
import PackageModel
import TSCBasic
import TSCUtility
import Xcodeproj

struct XcodeBuilder {

    // MARK: - Properties

    let path: AbsolutePath
    let project: Xcode.Project
    let package: PackageInfo
    let options: Command.Options

    var buildDirectory: Foundation.URL {
        self.package.projectBuildDirectory
            .appendingPathComponent("build")
            .absoluteURL
    }

    // MARK: - Initialisation

    init (project: Xcode.Project, projectPath: AbsolutePath, package: PackageInfo, options: Command.Options) {
        self.project = project
        self.path = projectPath
        self.package = package
        self.options = options
    }


    // MARK: - Clean

    func clean () throws {
        let process = TSCBasic.Process (
            arguments: [
                "xcrun",
                "xcodebuild",
                "-project", self.path.pathString,
                "BUILD_DIR=\(self.buildDirectory.path)",
                "clean"
            ],
            outputRedirection: .none
        )

        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw Error.nonZeroExit(code)
            }
        case let .signalled(signal: signal):
            throw Error.signalExit(signal)
        }
    }


    // MARK: - Build

    func build (targets: [String], sdk: TargetPlatform.SDK) throws -> [String: Foundation.URL] {
        let process = TSCBasic.Process (
            arguments: try self.buildCommand(targets: targets, sdk: sdk),
            outputRedirection: .none
        )

        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw Error.nonZeroExit(code)
            }
        case let .signalled(signal: signal):
            throw Error.signalExit(signal)
        }

        return targets
            .reduce(into: [String: Foundation.URL]()) { dict, name in
                dict[name] = self.frameworkPath(target: name, sdk: sdk)
            }
    }

    private func buildCommand (targets: [String], sdk: TargetPlatform.SDK) throws -> [String] {
        var command: [String] = [
            "xcrun",
            "xcodebuild",
            "-project", self.path.pathString,
            "-configuration", self.options.configuration.xcodeConfigurationName,
            "-sdk", sdk.sdkName,
            "BUILD_DIR=\(self.buildDirectory.path)"
        ]

        // add our targets
        command += targets.flatMap { [ "-target", $0 ] }

        // and the command
        command += [ "build" ]

        return command
    }

    // we should probably pull this from the build output but we just make assumptions here
    private func frameworkPath (target: String, sdk: TargetPlatform.SDK) -> Foundation.URL {
        return self.buildDirectory
            .appendingPathComponent(self.options.configuration.xcodeConfigurationName + sdk.directorySuffix)
            .appendingPathComponent("\(self.productName(target: target)).framework")
            .absoluteURL
    }


    // MARK: - Merging

    func merge (target: String, frameworks: [Foundation.URL]) throws -> Foundation.URL {
        let outputPath = self.xcframeworkPath(target: target)

        let process = TSCBasic.Process (
            arguments: self.mergeCommand(outputPath: outputPath, frameworks: frameworks),
            outputRedirection: .none
        )

        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw Error.nonZeroExit(code)
            }
        case let .signalled(signal: signal):
            throw Error.signalExit(signal)
        }

        return outputPath
    }

    private func mergeCommand (outputPath: Foundation.URL, frameworks: [Foundation.URL]) -> [String] {
        var command: [String] = [
            "xcrun",
            "xcodebuild",
            "-create-xcframework"
        ]

        // add our frameworks
        command += frameworks.flatMap { [ "-framework", $0.path ] }

        // and the output
        command += [ "-output", outputPath.path ]

        return command
    }

    private func xcframeworkPath (target: String) -> Foundation.URL {
        return URL(fileURLWithPath: self.options.output)
            .appendingPathComponent("\(self.productName(target: target)).xcframework")
    }

    private func productName (target: String) -> String {
        // Xcode replaces any non-alphanumeric characters in the target with an underscore
        // https://developer.apple.com/documentation/swift/imported_c_and_objective-c_apis/importing_swift_into_objective-c
        return target
            .replacingOccurrences(of: "[^0-9a-zA-Z]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "^[0-9]", with: "_", options: .regularExpression)

    }


    // MARK: - Errors

    enum Error: Swift.Error, LocalizedError {
        case nonZeroExit(Int32)
        case signalExit(Int32)

        var errorDescription: String? {
            switch self {
            case let .nonZeroExit(code):
                return "xcodebuild exited with a non-zero code: \(code)"
            case let .signalExit(signal):
                return "xcodebuild exited due to signal: \(signal)"
            }
        }
    }
}


// MARK: - Helper Extensions

extension BuildConfiguration {
    var xcodeConfigurationName: String {
        switch self {
        case .debug:        return "Debug"
        case .release:      return "Release"
        }
    }
}
