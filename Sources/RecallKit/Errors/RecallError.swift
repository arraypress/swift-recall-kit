//
//  RecallError.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why a search could not run at all. A source that can't be read is not an
/// error — it is a ``RecallSkip`` — unless no source could be read.
public enum RecallError: Error, Sendable, Equatable, LocalizedError {
    /// Neither words nor a person were given.
    case nothingToFind
    /// No source could be searched; each one's reason.
    case nothingSearched([RecallSkip])

    /// A sentence for a person.
    public var errorDescription: String? {
        switch self {
        case .nothingToFind:
            return "give words to find, a person, or both"
        case .nothingSearched(let skipped):
            return "nothing could be searched — " + skipped.map { "\($0.source.rawValue): \($0.reason)" }.joined(separator: "; ")
        }
    }
}
