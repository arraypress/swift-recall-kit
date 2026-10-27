//
//  WhatsAppSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  WhatsApp, through swift-whatsapp-messages. WhatsApp keeps its own names
//  (the address book's, the ones people chose), so a person is resolved by
//  its directory as well as by the phones Contacts has — and every address
//  is searched with its pair, as WhatsApp gives some people two.
//

import Foundation
import WhatsAppMessages

struct WhatsAppSearcher: RecallSearching {
    let store: WhatsAppStore
    let source = RecallSource.whatsapp

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        var addresses: [String]?
        if let person {
            let directory = store.directory
            let contacts = ([person.query] + person.phones + person.names).flatMap { directory.resolve($0) }
            let found = PersonMatch.unique(contacts.flatMap { directory.addresses(of: $0.jid) })
            guard !found.isEmpty else { throw SkipReason("nobody called \(person.query) in WhatsApp") }
            addresses = found
        }
        let titles = Dictionary(try store.chats(includeHidden: true).map { ($0.id, $0.name ?? $0.contact?.name ?? $0.jid) },
                                uniquingKeysWith: { first, _ in first })
        let messages = try store.messages(MessageQuery(text: query.text, fromJIDs: addresses, since: query.since,
                                                       until: query.until, limit: query.limit))
        let hits = messages.map { message in
            RecallHit(source: .whatsapp, id: String(message.id), date: message.date,
                      from: message.isFromMe ? "me" : message.sender.map { $0.name ?? $0.phone ?? $0.jid },
                      address: message.isFromMe ? nil : message.sender.map { $0.phone ?? $0.jid },
                      isFromMe: message.isFromMe, title: titles[message.chatID], conversation: message.chatID,
                      excerpt: Excerpt.around(query.text, in: message.text ?? message.media?.fileName ?? ""))
        }
        return (hits, 0)
    }
}
