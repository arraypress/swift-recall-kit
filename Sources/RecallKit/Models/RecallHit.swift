//
//  RecallHit.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One thing found — a mail, a message, a call, an event, a reminder, a note or a
/// recording — with the words around the match.
public struct RecallHit: Sendable, Equatable, Codable {
    /// Where it was found.
    public var source: RecallSource
    /// Its id in its own store — a Mail message id, a Messages or WhatsApp
    /// row, a note's id, an event's or a recording's identifier — what that
    /// source's own tool opens it by.
    public var id: String
    /// When it was sent, received or last changed.
    public var date: Date
    /// Who sent it — a name when one is known, else the address; nil for a note.
    public var from: String?
    /// The sender's address, when there is one.
    public var address: String?
    /// Whether the owner sent it.
    public var isFromMe: Bool
    /// The conversation, subject or note title it belongs to.
    public var title: String?
    /// The conversation's own row, for opening the thread around it.
    public var conversation: Int64?
    /// The words around the match (or the start, when only the sender matched).
    public var excerpt: String
    /// Where in a recording the words were said, in seconds.
    public var at: Double?
    /// What it sits in, by its own source's id — a Freeform item's board.
    public var parent: String?

    /// A hit.
    ///
    /// - Parameters:
    ///   - source: Where it was found.
    ///   - id: Its row in its own store.
    ///   - date: When it was sent or changed.
    ///   - from: Who sent it.
    ///   - address: The sender's address.
    ///   - isFromMe: Whether the owner sent it.
    ///   - title: The conversation, subject or note title.
    ///   - conversation: The conversation's row.
    ///   - excerpt: The words around the match.
    ///   - at: Where in a recording the words were said.
    ///   - parent: What it sits in, by its source's id.
    public init(source: RecallSource, id: String, date: Date, from: String? = nil, address: String? = nil,
                isFromMe: Bool = false, title: String? = nil, conversation: Int64? = nil, excerpt: String,
                at: Double? = nil, parent: String? = nil) {
        self.source = source
        self.id = id
        self.date = date
        self.from = from
        self.address = address
        self.isFromMe = isFromMe
        self.title = title
        self.conversation = conversation
        self.excerpt = excerpt
        self.at = at
        self.parent = parent
    }
}
