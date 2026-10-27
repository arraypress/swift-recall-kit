//
//  RecallSkip.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A source that was not searched, and why — no access, not installed, or
/// nothing it could match for this query. Reported, never hidden: "nothing
/// found" and "not looked at" must read differently.
public struct RecallSkip: Sendable, Equatable, Codable {
    /// The source.
    public var source: RecallSource
    /// Why, in a sentence.
    public var reason: String

    /// A skipped source.
    ///
    /// - Parameters:
    ///   - source: The source.
    ///   - reason: Why it was not searched.
    public init(source: RecallSource, reason: String) {
        self.source = source
        self.reason = reason
    }
}
