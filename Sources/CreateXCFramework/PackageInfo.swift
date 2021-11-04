//
//  PackageInfo.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import ArgumentParser
import Build
import Foundation
import PackageLoading
import PackageModel
import SPMBuildCore
import Workspace
import Xcodeproj

struct PackageInfo {

    // MARK: - Properties

    let rootDirectory: Foundation.URL
    let buildDirectory: Foundation.URL

    var projectBuildDirectory: Foundation.URL {
        return self.buildDirectory
            .appendingPathComponent("swift-create-xcframework")
            .absoluteURL
    }

    var hasDistributionBuildXcconfig: Bool {
        self.overridesXcconfig != nil || self.options.stackEvolution == false
    }

    var distributionBuildXcconfig: Foundation.URL {
        return self.projectBuildDirectory
            .appendingPathComponent("Distribution.xcconfig")
            .absoluteURL
    }

    var overridesXcconfig: Foundation.URL? {
        guard let path = self.options.xcconfig else { return nil }

        // absolute path
        if path.hasPrefix("/") {
            return Foundation.URL(fileURLWithPath: path)

        // strip current directory if thats where we are
        } else if path.hasPrefix("./") {
            return self.rootDirectory.appendingPathComponent(String(path[path.index(path.startIndex, offsetBy: 2)...]))
        }

        return self.rootDirectory.appendingPathComponent(path)
    }

    // TODO: Map diagnostics to swift-log
    let diagnostics = DiagnosticsEngine()

    let options: Command.Options
//    let package: Package
    let graph: PackageGraph
    let manifest: Manifest
    let toolchain: Toolchain
    let workspace: Workspace


    // MARK: - Initialisation

    init (options: Command.Options) throws {
        self.options = options
        self.rootDirectory = Foundation.URL(fileURLWithPath: options.packagePath, isDirectory: true).absoluteURL
        self.buildDirectory = self.rootDirectory.appendingPathComponent(options.buildPath, isDirectory: true).absoluteURL

        let root = AbsolutePath(self.rootDirectory.path)

        self.toolchain = try UserToolchain(destination: try .hostDestination())

        #if swift(>=5.5)
        let resources = try UserManifestResources(swiftCompiler: self.toolchain.swiftCompiler, swiftCompilerFlags: [])
        #else
        let resources = try UserManifestResources(swiftCompiler: self.toolchain.swiftCompiler)
        #endif
        let loader = ManifestLoader(manifestResources: resources)
        self.workspace = Workspace.create(forRootPackage: root, manifestLoader: loader)
        
        #if swift(>=5.5)
        self.graph = try self.workspace.loadPackageGraph(rootPath: root, diagnostics: self.diagnostics)
        let swiftCompiler = toolchain.swiftCompiler
        self.manifest = try tsc_await {
            ManifestLoader.loadRootManifest(
                at: root,
                swiftCompiler: swiftCompiler,
                swiftCompilerFlags: [],
                identityResolver: DefaultIdentityResolver(),
                on: DispatchQueue.global(qos: .background),
                completion: $0
            )
        }
        #else
        self.graph = self.workspace.loadPackageGraph(root: root, diagnostics: self.diagnostics)
        self.manifest = try ManifestLoader.loadManifest (
            packagePath: root,
            swiftCompiler: self.toolchain.swiftCompiler,
            packageKind: .root
        )
        #endif
    }


    // MARK: - Validation

    func validationErrors () -> [PackageValidationError] {
        var errors = [PackageValidationError]()

        // check the graph for binary targets
        let binary = self.graph.allTargets.filter { $0.type == .binary }
        if binary.isEmpty == false {
            errors.append(.containsBinaryTargets(binary.map(\.name)))
        }

        // check for system modules
        let system = self.graph.allTargets.filter { $0.type == .systemModule }
        if system.isEmpty == false {
            errors.append(.containsSystemModules(system.map(\.name)))
        }

        // and for conditional dependencies
        let conditionals = self.graph.allTargets.filter { $0.dependencies.contains { $0.conditions.isEmpty == false } }
        if conditionals.isEmpty == false {
            errors.append(.containsConditionalDependencies(conditionals.map(\.name)))
        }

        return errors
    }


    // MARK: - Product/Target Names

    func validProductNames (project: Xcode.Project) throws -> [String] {

        // find our build targets
        let productNames: [String]
        if self.options.products.isEmpty == false {
            productNames = self.options.products
        } else {
            productNames = self.manifest.libraryProductNames
        }

        // validation
        guard productNames.isEmpty == false else {
            throw ValidationError (
                "No products to create frameworks for were found. Add library products to Package.swift"
                    + " or specify products/targets on the command line."
            )
        }

        let xcodeTargetNames = project.frameworkTargets.map { $0.name }
        let invalidProducts = productNames.filter { xcodeTargetNames.contains($0) == false }
        guard invalidProducts.isEmpty == true else {

            let allLibraryProductNames = self.manifest.libraryProductNames
            let nonRootPackageTargets = xcodeTargetNames.filter { allLibraryProductNames.contains($0) == false }

            throw ValidationError (
                """
                Invalid product/target name(s):
                    \(invalidProducts.joined(separator: "\n    "))

                Available \(self.manifest.name) products:
                    \(allLibraryProductNames.sorted().joined(separator: "\n    "))

                Additional available targets:
                    \(nonRootPackageTargets.sorted().joined(separator: "\n    "))
                """
            )
        }

        return productNames
    }

    func printAllProducts (project: Xcode.Project) {
        let allLibraryProductNames = self.manifest.libraryProductNames
        let xcodeTargetNames = project.frameworkTargets.map { $0.name }
        let nonRootPackageTargets = xcodeTargetNames.filter { allLibraryProductNames.contains($0) == false }

        print (
            """
            \nAvailable \(self.manifest.name) products:
                \(allLibraryProductNames.sorted().joined(separator: "\n    "))

            Additional available targets:
                \(nonRootPackageTargets.sorted().joined(separator: "\n    "))
            \n
            """
        )
    }


    // MARK: - Platforms

    /// check if our command line platforms are supported by the package definition
    func supportedPlatforms () throws -> [TargetPlatform] {

        // if they have specified platforms all good, if not go everything except catalyst
        let supported = self.options.platform.nonEmpty ?? TargetPlatform.allCases.filter { $0 != .maccatalyst }

        // do we have package platforms defined?
        guard let packagePlatforms = self.manifest.platforms.nonEmpty else {
            return supported
        }

        // filter our package platforms to make sure everything is supported
        let target = packagePlatforms
            .compactMap { platform -> [TargetPlatform]? in
                return supported.filter({ $0.platformName == platform.platformName })
            }
            .flatMap { $0 }

        return target
    }


    // MARK: - Helpers

    private var absoluteRootDirectory: AbsolutePath {
        AbsolutePath(self.rootDirectory.path)
    }

}


// MARK: - Supported Platform Types

enum SupportedPlatforms {
    case noPackagePlatforms (plan: [SupportedPlatform])
    case packagePlatformsUnsupported (plan: [SupportedPlatform])
    case packageValid (plan: [SupportedPlatform])
}

extension SupportedPlatform: Comparable {
    public static func == (lhs: SupportedPlatform, rhs: SupportedPlatform) -> Bool {
        return lhs.platform == rhs.platform && lhs.version == rhs.version
    }

    public static func < (lhs: SupportedPlatform, rhs: SupportedPlatform) -> Bool {
        if lhs.platform == rhs.platform {
            return lhs.version < rhs.version
        }

        return lhs.platform.name < rhs.platform.name
    }
}

// MARK: - Validation Errors

enum PackageValidationError: LocalizedError {
    case containsBinaryTargets([String])
    case containsSystemModules([String])
    case containsConditionalDependencies([String])

    var isFatal: Bool {
        switch self {
        case .containsBinaryTargets, .containsSystemModules:
            return true
        case .containsConditionalDependencies:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case let .containsBinaryTargets(targets):
            return "Xcode project generation is not supported by Swift Package Manager for packages that contain binary targets."
                + "These binary targets were detected: \(targets.joined(separator: ", "))"
        case let .containsSystemModules(targets):
            return "Xcode project generation is not supported by Swift Package Manager for packages that reference system modules."
                + "These system modules were referenced: \(targets.joined(separator: ", "))"
        case let .containsConditionalDependencies(targets):
            return "Xcode project generation does not support conditional target dependencies, so the generated project may not build successfully."
                + "These targets contain conditional dependencies: \(targets.joined(separator: ", "))"
        }
    }
}
