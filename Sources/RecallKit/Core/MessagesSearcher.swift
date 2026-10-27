//
//  MessagesSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Messages, through swift-apple-messages. The database holds addresses,
//  not names: a person is searched by every phone and email Contacts has
//  for them, and senders are named from Contacts the same way.
//

import AppleMessages
import Foundation

struct MessagesSearcher: RecallSearching {
    let store: MessageStore
    /// Names for addresses; nil when Contacts could not be read.
    let names: ContactNames?
    /// Why Contacts could not be read, for the skip when a name can't be resolved.
    let contactsProblem: String?
    let source = RecallSource.messages

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        var senders: [String?] = [nil]
        if let person {
            senders = person.phones + person.emails
            guard !senders.isEmpty else {
                throw SkipReason(contactsProblem.map { "Contacts could not be read (\($0)), so \(person.query) has no address to search" }
                                 ?? "no phone number or email for \(person.query) in Contacts")
            }
        }
        let titles = Dictionary(uniqueKeysWithValues: try store.chats().map { ($0.id, title(of: $0)) })
        var found: [RecallHit] = []
        for sender in senders {
            let messages = try store.messages(MessageQuery(text: query.text, from: sender, since: query.since,
                                                           until: query.until, limit: query.limit))
            found += messages.map { message in
                let handle = message.sender.map { names?.named($0) ?? $0 }
                return RecallHit(source: .messages, id: String(message.id), date: message.date,
                                 from: message.isFromMe ? "me" : handle.map { $0.name ?? $0.address },
                                 address: message.isFromMe ? nil : handle?.address, isFromMe: message.isFromMe,
                                 title: message.chatID.flatMap { titles[$0] }, conversation: message.chatID,
                                 excerpt: Excerpt.around(query.text, in: message.text ?? ""))
            }
        }
        return (found, 0)
    }

    /// A conversation's name: its own, or the people in it.
    private func title(of chat: Chat) -> String {
        if let name = chat.displayName, !name.isEmpty { return name }
        let people = chat.participants.map { names?.named($0) ?? $0 }.map { $0.name ?? $0.address }
        return people.joined(separator: ", ")
    }
}
