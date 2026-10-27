//
//  RecallResult.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a search found, across every source it could read.
public struct RecallResult: Sendable, Equatable, Codable {
    /// The hits, newest first, at most the query's limit.
    public var hits: [RecallHit]
    /// How many each searched source matched before the limit.
    public var found: [RecallSource: Int]
    /// The sources not searched, and why.
    public var skipped: [RecallSkip]
    /// Who the person query turned out to be, when there was one.
    public var person: RecallPerson?
    /// Mail bodies and notes that could not be read when bodies were asked
    /// for — mail kept only on the server is the usual reason.
    public var unreadBodies: Int

    /// A result.
    ///
    /// - Parameters:
    ///   - hits: The hits, newest first.
    ///   - found: How many each source matched.
    ///   - skipped: The sources not searched.
    ///   - person: Who the person query turned out to be.
    ///   - unreadBodies: Bodies that could not be read.
    public init(hits: [RecallHit], found: [RecallSource: Int], skipped: [RecallSkip], person: RecallPerson? = nil,
                unreadBodies: Int = 0) {
        self.hits = hits
        self.found = found
        self.skipped = skipped
        self.person = person
        self.unreadBodies = unreadBodies
    }
}
