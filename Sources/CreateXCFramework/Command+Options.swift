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
        
        @Option(default: ".", help: ArgumentHelp("The location of the Package", valueName: "directory"))
        var packagePath: String
        
        
        // MARK: - Building
        
        @Option(default: ".build", help: ArgumentHelp("The location of the build/cache directory to use", valueName: "directory"))
        var buildPath: String
        
        @Option(default: .release, help: ArgumentHelp("Build with a specific configuration", valueName: "debug|release"))
        var configuration: PackageModel.BuildConfiguration
        
        @Flag(default: true, inversion: .prefixedNo, help: "Whether to clean before we build")
        var clean: Bool
        
        @Flag(help: "Prints the available products and targets")
        var listProducts: Bool
        
        
        // MARK: - Output Options
        
        @Option(help: ArgumentHelp("A list of platforms you want to build for. Can be specified multiple times. Default is to build for all platforms supported in your Package.swift, or all Apple platforms if omitted", valueName: TargetPlatform.allCases.map({ $0.rawValue }).joined(separator: "|")))
        var platform: [TargetPlatform]
        
        @Option(default: ".", help: ArgumentHelp("Where to place the compiled .xcframework(s)", valueName: "directory"))
        var output: String
        
        @Flag(help: "Whether to wrap the .xcframework(s) up in a versioned zip file ready for deployment")
        var zip: Bool
        
        
        // MARK: - Targets
        
        @Argument(help: "An optional list of products (or targets) to build. Defaults to building all `.library` products")
        var products: [String]
    }
}


// MARK: - ParsableArguments Extensions

extension PackageModel.BuildConfiguration: ExpressibleByArgument {}
