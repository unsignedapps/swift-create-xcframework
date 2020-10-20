//
//  Constants.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 9/5/20.
//

import ArgumentParser
import PackageModel

enum TargetPlatform: String, ExpressibleByArgument, CaseIterable {
    case ios
    case macos
    case tvos
    case watchos

    init?(argument: String) {
        self.init(rawValue: argument.lowercased())
    }


    // MARK: - Target SDKs

    struct SDK {
        let sdkName: String
        let directorySuffix: String
    }

    var sdks: [SDK] {
        switch self {
        case .ios:
            return [
                SDK(sdkName: "iphoneos", directorySuffix: "-iphoneos"),
                SDK(sdkName: "iphonesimulator", directorySuffix: "-iphonesimulator")
            ]

        case .macos:
            return [
                SDK(sdkName: "macosx", directorySuffix: "")
            ]

        case .tvos:
            return [
                SDK(sdkName: "appletvos", directorySuffix: "-appletvos"),
                SDK(sdkName: "appletvsimulator", directorySuffix: "-appletvsimulator")
            ]

        case .watchos:
            return [
                SDK(sdkName: "watchos", directorySuffix: "-watchos"),
                SDK(sdkName: "watchsimulator", directorySuffix: "-watchsimulator")
            ]
        }
    }
}
