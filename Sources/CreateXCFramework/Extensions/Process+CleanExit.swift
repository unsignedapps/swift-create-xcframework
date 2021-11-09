//
//  Process+CleanExit.swift
//  swift-create-xcframework
//
//  Created by Rob Amos on 9/11/21.
//

import TSCBasic
import Foundation

extension TSCBasic.Process {

    @discardableResult
    func waitUntilCleanExit() throws -> ProcessResult {
        let command = self.arguments.command
        let result = try self.waitUntilExit()

        switch result.exitStatus {
        case let .terminated(code: code):
            if code != 0 {
                throw ProcessError.nonZeroExit(command, code)
            }
        case let .signalled(signal: signal):
            throw ProcessError.signalExit(command, signal)
        }

        return result
    }
}

enum ProcessError: Swift.Error, LocalizedError {
    case nonZeroExit(String, Int32)
    case signalExit(String, Int32)

    var errorDescription: String? {
        switch self {
        case let .nonZeroExit(command, code):
            return "\(command) exited with a non-zero code: \(code)"
        case let .signalExit(command, signal):
            return "\(command) exited due to signal: \(signal)"
        }
    }
}


private extension Array where Element == String {
    var command: String {
        guard let first = self.first else {
            return "<command>"
        }
        if first == "xcrun" && self.count > 1 {
            return self[1]
        }
        return first
    }
}
