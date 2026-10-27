//
//  RecallQuery.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What to look for: words, a person, or both, in a stretch of time.
///
/// ```swift
/// // What anybody said about the dentist this year.
/// let query = RecallQuery(text: "dentist", since: startOfYear)
/// // What Alex sent about the flat.
/// let fromAlex = RecallQuery(text: "flat", person: "Alex")
/// ```
public struct RecallQuery: Sendable, Equatable {
    /// Words to find, matched ignoring case. Nil finds everything a person sent.
    public var text: String?
    /// A name, phone number or email address: only what that person sent.
    /// A name is looked up in Contacts (and WhatsApp's own names).
    public var person: String?
    /// The earliest date.
    public var since: Date?
    /// The latest date.
    public var until: Date?
    /// Where to search; all of them by default.
    public var sources: Set<RecallSource>
    /// How many results, newest first, across every source.
    public var limit: Int
    /// Also read whole bodies — mail on this Mac and whole notes — not just
    /// what the indexes hold. Slower; capped by ``bodyBudget``.
    public var bodies: Bool
    /// The most mail bodies and notes read when ``bodies`` is on, newest first.
    public var bodyBudget: Int

    /// A query.
    ///
    /// - Parameters:
    ///   - text: Words to find.
    ///   - person: A name, phone number or email address.
    ///   - since: The earliest date.
    ///   - until: The latest date.
    ///   - sources: Where to search.
    ///   - limit: How many results, newest first.
    ///   - bodies: Also read whole bodies.
    ///   - bodyBudget: The most bodies read when `bodies` is on.
    public init(text: String? = nil, person: String? = nil, since: Date? = nil, until: Date? = nil,
                sources: Set<RecallSource> = Set(RecallSource.allCases), limit: Int = 50,
                bodies: Bool = false, bodyBudget: Int = 500) {
        self.text = text
        self.person = person
        self.since = since
        self.until = until
        self.sources = sources
        self.limit = limit
        self.bodies = bodies
        self.bodyBudget = bodyBudget
    }
}
