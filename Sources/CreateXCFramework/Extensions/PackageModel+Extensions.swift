//
//  PackageDescription+Extensions.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 7/5/20.
//

import PackageModel

extension ProductType {
    var isLibrary: Bool {
        if case .library = self {
            return true
        }
        return false
    }

    var isDynamicLibrary: Bool {
        if case .library(let type) = self {
            return type == .dynamic
        }
        return false
    }
}

extension Manifest {
    var libraryProductNames: [String] {
        return self.products
            .compactMap { product in
                guard product.type.isLibrary else { return nil }
                return product.name
            }
    }

    var dynamicLibraryProductNames: [String] {
        return self.supportedProducts
            .map { $0.name }
    }

    var supportedProducts: [ProductDescription] {
        return self.products
            .filter { $0.type.isDynamicLibrary }
    }

    var unsupportedProducts: [ProductDescription] {
        return self.products
            .filter { $0.type.isDynamicLibrary == false }
    }
}
