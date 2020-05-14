//
//  Xcodeproj+ProductValidation.swift
//  swift-create-xcframeworks
//
//  Created by Rob Amos on 8/5/20.
//

import Foundation
import Xcodeproj

extension Xcode.Project {
    var frameworkTargets: [Xcode.Target] {
        targets.filter { $0.productType == .framework }
    }
}
