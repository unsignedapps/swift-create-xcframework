//
//  ProjectGenerator.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import Foundation
import TSCBasic
import Xcodeproj

struct ProjectGenerator {
    
    private enum Constants {
        static let `extension` = "xcodeproj"
    }
    
    // MARK: - Properties
    
    let package: PackageInfo
    
    var projectPath: AbsolutePath {
        let dir = AbsolutePath(self.package.projectBuildDirectory.path)
        return buildXcodeprojPath(outputDir: dir, projectName: self.package.package.name)
    }
    
    // MARK: - Initialisation
    
    init (package: PackageInfo) {
        self.package = package
    }
    
    // MARK: - Generation
    
    func generate () throws -> Xcode.Project {
        let path = self.projectPath
        try makeDirectories(path)
        
        return try Xcodeproj.generate (
            projectName: self.package.package.name,
            xcodeprojPath: path,
            graph: self.package.graph,
            options: XcodeprojOptions(addExtraFiles: false),
            diagnostics: self.package.diagnostics
        )
    }
    
    private func createDirectory (at path: URL)  throws {
        guard FileManager.default.fileExists(atPath: path.path) == false else { return }
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
    }
}
