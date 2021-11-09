//
//  BuildResult.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 9/11/21.
//

import Foundation

struct BuildResult {
    let target: String
    let frameworkPath: Foundation.URL
    let debugSymbolsPath: Foundation.URL
}
