//
//  RecallAvailability.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Whether a source can be read on this Mac, and if not, why.
public struct RecallAvailability: Sendable, Equatable, Codable {
    /// The source.
    public var source: RecallSource
    /// Whether its store opened.
    public var readable: Bool
    /// Why it didn't — no Full Disk Access, the app not installed — or nil.
    public var reason: String?

    /// An availability.
    ///
    /// - Parameters:
    ///   - source: The source.
    ///   - readable: Whether its store opened.
    ///   - reason: Why it didn't.
    public init(source: RecallSource, readable: Bool, reason: String? = nil) {
        self.source = source
        self.readable = readable
        self.reason = reason
    }
}
