//
//  Zipper.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 13/5/20.
//

#if canImport(Basics)
import Basics
#endif
import Foundation
#if swift(>=5.6)
import PackageGraph
#endif
import PackageModel
import TSCBasic
import Workspace

struct Zipper {

    // MARK: - Properties

    let package: PackageInfo

    init (package: PackageInfo) {
        self.package = package
    }


    // MARK: - Zippering

    func zip (target: String, version: String?, file: Foundation.URL) throws -> Foundation.URL {

        let suffix = self.versionSuffix(target: target, default: version) ?? ""
        let zipPath = file.path.replacingOccurrences(of: "\\.xcframework$", with: "\(suffix).zip", options: .regularExpression)
        let zipURL = URL(fileURLWithPath: zipPath)

        let process = TSCBasic.Process (
            arguments: self.zipCommand(source: file, target: zipURL),
            outputRedirection: .none
        )

        print("\nPackaging \(file.path) into \(zipURL.path)\n\n")
        try process.launch()
        let result = try process.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw XcodeBuilder.Error.nonZeroExit("ditto", code)
            }
        case let .signalled(signal: signal):
            throw XcodeBuilder.Error.signalExit("ditto", signal)
        }

        return zipURL
    }

    func checksum (file: Foundation.URL) throws -> Foundation.URL {
#if swift(>=5.7)
        let sum = try checksum(forBinaryArtifactAt: AbsolutePath(validating: file.path))
#elseif swift(>=5.6)
        let sum = try self.package.workspace.checksum(forBinaryArtifactAt: AbsolutePath(file.path))
#else
        let sum = self.package.workspace.checksum(forBinaryArtifactAt: AbsolutePath(file.path), diagnostics: self.package.diagnostics)
#endif
        let checksumFile = file.deletingPathExtension().appendingPathExtension("sha256")
        try Data(sum.utf8).write(to: checksumFile)
        return checksumFile
    }

    private func zipCommand (source: Foundation.URL, target: Foundation.URL) -> [String] {
        return [
            "ditto",
            "-c",
            "-k",
            "--keepParent",
            source.path,
            target.path
        ]
    }

    private func versionSuffix (target: String, default fallback: String?) -> String? {

        // find the package that contains our target
        guard let packageRef = self.package.graph.packages.first(where: { $0.targets.contains(where: { $0.name == target }) }) else { return nil }

#if swift(>=5.6)
        guard
            let dependency = self.package.workspace.state.dependencies[packageRef.identity],
            case let .custom(version, _) = dependency.state
        else {
            return fallback.flatMap { "-" + $0 }
        }
#else
        guard
            let dependency = self.package.workspace.state.dependencies[forNameOrIdentity: packageRef.packageName],
            case let .checkout(checkout) = dependency.state,
            let version = checkout.version
        else {
            return fallback.flatMap { "-" + $0 }
        }
#endif

        return "-" + version.description
    }


    // MARK: - Cleaning

    func clean (file: Foundation.URL) throws {
        try FileManager.default.removeItem(at: file)
    }

    #if swift(>=5.7)
    private func checksum(forBinaryArtifactAt path: AbsolutePath) throws -> String {
        let fileSystem = localFileSystem
        let checksumAlgorithm = SHA256()
        let archiver = ZipArchiver(fileSystem: fileSystem)

        // Validate the path has a supported extension.
        guard let pathExtension = path.extension, archiver.supportedExtensions.contains(pathExtension) else {
            let supportedExtensionList = archiver.supportedExtensions.joined(separator: ", ")
            throw StringError("unexpected file type; supported extensions are: \(supportedExtensionList)")
        }

        // Ensure that the path with the accepted extension is a file.
        guard fileSystem.isFile(path) else {
            throw StringError("file not found at path: \(path.pathString)")
        }

        let contents = try fileSystem.readFileContents(path)
        return checksumAlgorithm.hash(contents).hexadecimalRepresentation
    }
    #endif
}

#if swift(>=5.6)
// Intentionally left blank
#elseif swift(>=5.5)
private extension ResolvedPackage {
    var packageName: String {
        self.manifestName
    }
}
#else
private extension ResolvedPackage {
    var packageName: String {
        self.name
    }
}
#endif
