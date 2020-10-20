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
    let package: Package
    let graph: PackageGraph
    let manifest: Manifest
    let toolchain: Toolchain
    let workspace: Workspace


    // MARJ: - Initialisation

    init (options: Command.Options) throws {
        self.options = options
        self.rootDirectory = Foundation.URL(fileURLWithPath: options.packagePath, isDirectory: true).absoluteURL
        self.buildDirectory = self.rootDirectory.appendingPathComponent(options.buildPath, isDirectory: true).absoluteURL

        let root = AbsolutePath(self.rootDirectory.path)

        self.toolchain = try UserToolchain(destination: try .hostDestination())

        let resources = try UserManifestResources(swiftCompiler: self.toolchain.swiftCompiler, swiftCompilerFlags: self.toolchain.extraSwiftCFlags)
        let loader = ManifestLoader(manifestResources: resources)
        self.workspace = Workspace.create(forRootPackage: root, manifestLoader: loader)

        self.package = try PackageBuilder.loadPackage (
            packagePath: root,
            swiftCompiler: self.toolchain.swiftCompiler,
            swiftCompilerFlags: self.toolchain.extraSwiftCFlags,
            xcTestMinimumDeploymentTargets: [:],
            diagnostics: self.diagnostics
        )

        self.graph = self.workspace.loadPackageGraph(root: root, diagnostics: self.diagnostics)

        self.manifest = try ManifestLoader.loadManifest (
            packagePath: root,
            swiftCompiler: self.toolchain.swiftCompiler,
            swiftCompilerFlags: self.toolchain.extraSwiftCFlags,
            packageKind: .root
        )
    }


    // MARK: - Product/Target Names

    func validProductNames (project: Xcode.Project) throws -> [String] {

        // find our build targets
        let productNames: [String]
        if self.options.products.isEmpty == false {
            productNames = self.options.products
        } else {
            productNames = package.manifest.libraryProductNames
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

            let allLibraryProductNames = self.package.manifest.libraryProductNames
            let nonRootPackageTargets = xcodeTargetNames.filter { allLibraryProductNames.contains($0) == false }

            throw ValidationError (
                """
                Invalid product/target name(s):
                    \(invalidProducts.joined(separator: "\n    "))

                Available \(self.package.name) products:
                    \(allLibraryProductNames.sorted().joined(separator: "\n    "))

                Additional available targets:
                    \(nonRootPackageTargets.sorted().joined(separator: "\n    "))
                """
            )
        }

        return productNames
    }

    func printAllProducts (project: Xcode.Project) {
        let allLibraryProductNames = self.package.manifest.libraryProductNames
        let xcodeTargetNames = project.frameworkTargets.map { $0.name }
        let nonRootPackageTargets = xcodeTargetNames.filter { allLibraryProductNames.contains($0) == false }

        print (
            """
            \nAvailable \(self.package.name) products:
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

        let supported = self.options.platform.nonEmpty ?? TargetPlatform.allCases

        // do we have package platforms defined?
        guard let packagePlatforms = self.manifest.platforms.nonEmpty else {
            return supported
        }

        // filter our package platforms to make sure everything is supported
        let target = packagePlatforms
            .compactMap { platform -> TargetPlatform? in
                return supported.first(where: { $0.rawValue == platform.platformName })
            }

        // are they different then?
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

extension SupportedPlatform: Equatable, Comparable {
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
