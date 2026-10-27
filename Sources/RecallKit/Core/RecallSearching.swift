//
//  RecallSearching.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One source a search can read. Each wraps its own library's store; tests
/// stand in their own.
protocol RecallSearching {
    /// Which source it reads.
    var source: RecallSource { get }

    /// The hits for a query, the person already resolved, and how many
    /// bodies could not be read. Throws ``SkipReason`` when this source has
    /// nothing it could match for the query.
    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int)
}
