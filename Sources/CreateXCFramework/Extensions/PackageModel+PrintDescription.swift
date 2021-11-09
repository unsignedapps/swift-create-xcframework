//
//  PackageModel+PrintDescription.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 9/11/21.
//

import PackageModel

extension ProductDescription {
    var printDescription: String {
        return "\(self.name) (\(self.type.printDescription)"
    }
}

extension ProductType {
    var printDescription: String {
        switch self {
        case .executable:           return "Executable"
        case .library(let type):    return "Library - \(type.printDescription))"
        case .plugin:               return "Plugin"
        case .test:                 return "Test"
        }
    }
}

private extension ProductType.LibraryType {
    var printDescription: String {
        switch self {
        case .dynamic:              return "Dynamic"
        case .static:               return "Static"
        case .automatic:            return "Automatic"
        }
    }
}
