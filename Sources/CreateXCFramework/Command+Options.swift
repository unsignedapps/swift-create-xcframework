//
//  Command+Options.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import ArgumentParser
import PackageModel

extension Command {
    struct Options: ParsableArguments {
        
        // MARK: - Package Loading
        
        @Option(default: ".", help: "The location of the Package.")
        var packagePath: String
        
        
        // MARK: - Building
        
        @Option(default: ".build", help: "The location of the build/cache directory to use.")
        var buildPath: String
        
        @Option(default: .release, help: "Build with a specific configuration (debug or release).")
        var configuration: PackageModel.BuildConfiguration
        
        @Flag(default: true, inversion: .prefixedNo, help: "Whether to clean before we build.")
        var clean: Bool
        
        @Flag(help: "Prints the available products and targets")
        var listProducts: Bool
        
        
        // MARK: - Output Options
        
        @Option(help: "A list of platforms you want to build for. Can be specified multiple times. Default is to build for all platforms supported in your Package.swift, or all Apple platforms if omitted.")
        var platform: [TargetPlatform]
        
        @Option(default: ".", help: "Where to place the compiled .xcframework(s)")
        var output: String
        
        @Flag(help: "Whether to wrap the .xcframework(s) up in a versioned zip file ready for deployment.")
        var zip: Bool
        
        
        // MARK: - Targets
        
        @Argument(help: "An optional list of products (or targets) to build. Defaults to building all `.library` products.")
        var products: [String]
    }
}


// MARK: - ParsableArguments Extensions

extension PackageModel.BuildConfiguration: ExpressibleByArgument {}
