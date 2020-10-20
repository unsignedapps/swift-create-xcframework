//
//  ProjectGenerator.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import Foundation
import TSCBasic
import TSCUtility
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

    /// Writes out the Xcconfig file
    func writeDistributionXcconfig () throws {
        try makeDirectories(self.projectPath)

        let path = AbsolutePath(self.package.distributionBuildXcconfig.path)
        try open(path) { stream in
            if let absolutePath = self.package.overridesXcconfig?.path {
                stream (
                    """
                    #include "\(AbsolutePath(absolutePath).relative(to: AbsolutePath(path.dirname)).pathString)"

                    """
                )
            }

            stream (
                """
                BUILD_LIBRARY_FOR_DISTRIBUTION=YES
                """
            )
        }
    }

    /// Generate an Xcode project.
    ///
    /// This is basically a copy of Xcodeproj.generate()
    ///
    func generate () throws -> Xcode.Project {
        let path = self.projectPath
        try makeDirectories(path)

        // Generate the contents of project.xcodeproj (inside the .xcodeproj).
        let project = try pbxproj (
            xcodeprojPath: path,
            graph: self.package.graph,
            extraDirs: [],
            extraFiles: [],
            options: XcodeprojOptions(xcconfigOverrides: (self.package.overridesXcconfig?.path).flatMap { AbsolutePath($0) }),
            diagnostics: self.package.diagnostics
        )

        return project
    }

}


// MARK: - Saving Xcode Projects

extension Xcode.Project {

    /// This is the group that is normally created in Xcodeproj.xcodeProject() when you specify an xcconfigOverride
    var configGroup: Xcode.Group {
        let name = "Configs"

        if let group = self.mainGroup.subitems.lazy.compactMap({ $0 as? Xcode.Group }).first(where: { $0.name == name }) {
            return group
        }

        // doesn't exist - lets creat it
        return self.mainGroup.addGroup(path: "", name: name)
    }

    func enableDistribution (targets: [String], xcconfig: RelativePath) throws {
        let group = self.configGroup
        let ref = group.addFileReference (
            path: xcconfig.pathString,
            name: xcconfig.basename
        )

        for target in self.targets where targets.contains(target.name) {
            target.buildSettings.xcconfigFileRef = ref
        }
    }

    func save (to path: AbsolutePath) throws {
        try open(path.appending(component: "project.pbxproj")) { stream in
            // Serialize the project model we created to a plist, and return
            // its string description.
            let str = "// !$*UTF8*$!\n" + self.generatePlist().description
            stream(str)
        }

        for target in self.frameworkTargets {
            ///// For framework targets, generate target.c99Name_Info.plist files in the
            ///// directory that Xcode project is generated
            let name = "\(target.name.spm_mangledToC99ExtendedIdentifier())_Info.plist"
            try open(path.appending(RelativePath(name))) { print in
                print(
                    """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <plist version="1.0">
                    <dict>
                    <key>CFBundleDevelopmentRegion</key>
                    <string>en</string>
                    <key>CFBundleExecutable</key>
                    <string>$(EXECUTABLE_NAME)</string>
                    <key>CFBundleIdentifier</key>
                    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
                    <key>CFBundleInfoDictionaryVersion</key>
                    <string>6.0</string>
                    <key>CFBundleName</key>
                    <string>$(PRODUCT_NAME)</string>
                    <key>CFBundlePackageType</key>
                    <string>FMWK</string>
                    <key>CFBundleShortVersionString</key>
                    <string>1.0</string>
                    <key>CFBundleSignature</key>
                    <string>????</string>
                    <key>CFBundleVersion</key>
                    <string>$(CURRENT_PROJECT_VERSION)</string>
                    <key>NSPrincipalClass</key>
                    <string></string>
                    </dict>
                    </plist>
                    """
                )
            }
        }
    }
}

/// Writes the contents to the file specified.
///
/// This method doesn't rewrite the file in case the new and old contents of
/// file are same.
private func open(_ path: AbsolutePath, body: ((String) -> Void) throws -> Void) throws {
    let stream = BufferedOutputByteStream()
    try body { line in
        stream <<< line
        stream <<< "\n"
    }
    // If the file exists with the identical contents, we don't need to rewrite it.
    //
    // This avoids unnecessarily triggering Xcode reloads of the project file.
    if let contents = try? localFileSystem.readFileContents(path), contents == stream.bytes {
        return
    }

    // Write the real file.
    try localFileSystem.writeFileContents(path, bytes: stream.bytes)
}
