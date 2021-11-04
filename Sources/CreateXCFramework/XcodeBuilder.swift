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
                throw Error.nonZeroExit("xcodebuild", code)
            }
        case let .signalled(signal: signal):
            throw Error.signalExit("xcodebuild", signal)
        }
    }


    // MARK: - Build

    struct BuildResult {
        let target: String
        let frameworkPath: Foundation.URL
        let debugSymbolsPath: Foundation.URL
    }

    func build (targets: [String], sdk: TargetPlatform.SDK) throws -> [String: BuildResult] {
        for target in targets {
            let process = TSCBasic.Process (
                arguments: try self.buildCommand(target: target, sdk: sdk),
                outputRedirection: .none
            )

            try process.launch()
            let result = try process.waitUntilExit()

            switch result.exitStatus {
            case let .terminated(code: code):
                if code != 0 {
                    throw Error.nonZeroExit("xcodebuild", code)
                }
            case let .signalled(signal: signal):
                throw Error.signalExit("xcodebuild", signal)
            }
        }

        return targets
            .reduce(into: [String: BuildResult]()) { dict, name in
                dict[name] = BuildResult (
                    target: name,
                    frameworkPath: self.frameworkPath(target: name, sdk: sdk),
                    debugSymbolsPath: self.debugSymbolsPath(target: name, sdk: sdk)
                )
            }
    }

    private func buildCommand (target: String, sdk: TargetPlatform.SDK) throws -> [String] {
        var command: [String] = [
            "xcrun",
            "xcodebuild",
            "-project", self.path.pathString,
            "-configuration", self.options.configuration.xcodeConfigurationName,
            "-archivePath", self.buildDirectory.appendingPathComponent(self.productName(target: target)).appendingPathComponent(sdk.archiveName).path,
            "-destination", sdk.destination,
            "BUILD_DIR=\(self.buildDirectory.path)",
            "SKIP_INSTALL=NO"
        ]

        // add SDK-specific build settings
        if let settings = sdk.buildSettings {
            for setting in settings {
                command.append("\(setting.key)=\(setting.value)")
            }
        }

        // enable evolution for the whole stack
        if self.options.stackEvolution {
            command.append("BUILD_LIBRARY_FOR_DISTRIBUTION=YES")
        }

        // add build settings provided in the invocation
        self.options.xcSetting.forEach { setting in
            command.append("\(setting.name)=\(setting.value)")
        }

        // add our targets
        command += [ "-scheme", target ]

        // and the command
        command += [ "archive" ]

        return command
    }

    // we should probably pull this from the build output but we just make assumptions here
    private func frameworkPath (target: String, sdk: TargetPlatform.SDK) -> Foundation.URL {
        return self.buildDirectory
            .appendingPathComponent(self.productName(target: target))
            .appendingPathComponent(sdk.archiveName)
            .appendingPathComponent("Products/Library/Frameworks")
            .appendingPathComponent("\(self.productName(target: target)).framework")
            .absoluteURL
    }

    // MARK: - Debug Symbols

    private func debugSymbolsPath (target: String, sdk: TargetPlatform.SDK) -> Foundation.URL {
        return self.buildDirectory
            .appendingPathComponent(sdk.releaseFolder)
    }

    private func dSYMPath (target: String, path: Foundation.URL) -> Foundation.URL {
        return path
            .appendingPathComponent("\(self.productName(target: target)).framework.dSYM")
    }

    private func dwarfPath (target: String, path: Foundation.URL) -> Foundation.URL {
        return path
            .appendingPathComponent("Contents/Resources/DWARF")
            .appendingPathComponent(self.productName(target: target))
    }

    private func debugSymbolFiles (target: String, path: Foundation.URL) throws -> [Foundation.URL] {

        // if there is no dSYM directory there is no point continuing
        let dsym = self.dSYMPath(target: target, path: path)
        guard FileManager.default.fileExists(atPath: dsym.absoluteURL.path) else {
            return []
        }

        var files = [
            dsym
        ]

        // if we have a dwarf file we can inspect that to get the slice UUIDs
        let dwarf = self.dwarfPath(target: target, path: dsym)
        guard FileManager.default.fileExists(atPath: dwarf.absoluteURL.path) else {
            return files
        }

        // get the UUID of the slices in the DWARF
        let identifiers = try self.binarySliceIdentifiers(file: dwarf)

        // They should be bcsymbolmap files in the debug dir
        for identifier in identifiers {
            let file = "\(identifier.uuidString.uppercased()).bcsymbolmap"
            files.append(path.appendingPathComponent(file))
        }

        return files
    }

    private func binarySliceIdentifiers (file: Foundation.URL) throws -> [UUID] {
        let command = [
            "xcrun",
            "dwarfdump",
            "--uuid",
            file.absoluteURL.path
        ]

        let process = TSCBasic.Process (
            arguments: command,
            outputRedirection: .collect
        )

        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw Error.nonZeroExit("dwarfdump", code)
            }

        case let .signalled(signal: signal):
            throw Error.signalExit("dwarfdump", signal)
        }

        switch result.output {
        case let .success(output):
            guard let string = String(bytes: output, encoding: .utf8) else {
                return []
            }
            return try string.sliceIdentifiers()

        case let .failure(error):
            throw Error.errorThrown("dwarfdump", error)
        }
    }


    // MARK: - Merging

    func merge (target: String, buildResults: [BuildResult]) throws -> Foundation.URL {
        let outputPath = self.xcframeworkPath(target: target)

        // try to remove it if its already there, otherwise we're going to get errors
        try? FileManager.default.removeItem(at: outputPath)

        let process = TSCBasic.Process (
            arguments: try self.mergeCommand(outputPath: outputPath, buildResults: buildResults),
            outputRedirection: .none
        )

        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw Error.nonZeroExit("xcodebuild", code)
            }
        case let .signalled(signal: signal):
            throw Error.signalExit("xcodebuild", signal)
        }

        return outputPath
    }

    private func mergeCommand (outputPath: Foundation.URL, buildResults: [BuildResult]) throws -> [String] {
        var command: [String] = [
            "xcrun",
            "xcodebuild",
            "-create-xcframework"
        ]

        // add our frameworks and any debugging symbols
        command += try buildResults.flatMap { result -> [String] in
            var args = [ "-framework", result.frameworkPath.absoluteURL.path ]

            if self.package.options.debugSymbols {
                let symbolFiles = try self.debugSymbolFiles(target: result.target, path: result.debugSymbolsPath)
                for file in symbolFiles {
                    if FileManager.default.fileExists(atPath: file.absoluteURL.path) {
                        args += [ "-debug-symbols", file.absoluteURL.path ]
                    }
                }

            }

            return args
        }

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
        case nonZeroExit(String, Int32)
        case signalExit(String, Int32)
        case errorThrown(String, Swift.Error)

        var errorDescription: String? {
            switch self {
            case let .nonZeroExit(command, code):
                return "\(command) exited with a non-zero code: \(code)"
            case let .signalExit(command, signal):
                return "\(command) exited due to signal: \(signal)"
            case let .errorThrown(command, error):
                return "\(command) returned unexpected error: \(error)"
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

private extension String {
    func sliceIdentifiers() throws -> [UUID] {
        let regex = try NSRegularExpression(pattern: #"^UUID: ([a-zA-Z0-9\-]+)"#, options: .anchorsMatchLines)
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))

        guard matches.isEmpty == false else {
            return []
        }

        return matches
            .compactMap { match in
                let nsrange = match.range(at: 1)
                guard let range = Range(nsrange, in: self) else {
                    return nil
                }
                return String(self[range])
            }
            .compactMap(UUID.init(uuidString:))
    }
}
