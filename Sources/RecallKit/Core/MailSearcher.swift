//
//  MailSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Mail, through swift-apple-mail. Its index holds subjects and senders, not
//  bodies — and Spotlight indexes no mail (measured in that library), so a
//  body search means reading message files: with `bodies`, the newest
//  `bodyBudget` candidates are read, and those only on the server counted.
//

import AppleMail
import Foundation

struct MailSearcher: RecallSearching {
    let store: MailStore
    let source = RecallSource.mail

    func hits(for query: RecallQuery, person: RecallPerson?) throws -> (hits: [RecallHit], unreadBodies: Int) {
        let senders = MailSearcher.senders(for: person)
        var found: [RecallHit] = []
        for sender in senders {
            let matches = try store.search(MailQuery(text: query.text, from: sender, since: query.since, until: query.until,
                                                     incomingOnly: false, limit: query.limit))
            found += matches.map { hit($0, excerpt: Excerpt.around(query.text, in: $0.displaySubject)) }
        }
        var unread = 0
        if query.bodies, let text = query.text {
            let matched = Set(found.map(\.id))
            for sender in senders {
                let candidates = try store.search(MailQuery(from: sender, since: query.since, until: query.until,
                                                            incomingOnly: false, limit: query.bodyBudget))
                for message in candidates where !matched.contains(message.id) {
                    guard let body = try? store.body(of: message.id) else { unread += 1; continue }
                    if Excerpt.matches(text, in: body.text) {
                        found.append(hit(message, excerpt: Excerpt.around(text, in: body.text)))
                    }
                }
            }
        }
        return (found, unread)
    }

    /// Who to search mail from: each email of the person, or the names when
    /// there is none, or what was typed; nil — anyone — for no person.
    static func senders(for person: RecallPerson?) -> [String?] {
        guard let person else { return [nil] }
        if !person.emails.isEmpty { return person.emails }
        if !person.names.isEmpty { return person.names }
        return [person.query]
    }

    private func hit(_ message: Message, excerpt: String) -> RecallHit {
        RecallHit(source: .mail, id: message.id, date: message.receivedAt, from: message.sender.shortName,
                  address: message.sender.address, isFromMe: MailSearcher.isSent(message.mailbox),
                  title: message.displaySubject, conversation: message.conversationID, excerpt: excerpt)
    }

    /// Whether a mailbox holds mail the owner sent: its last part names it.
    static func isSent(_ mailbox: String) -> Bool {
        let last = (mailbox.removingPercentEncoding ?? mailbox).split(separator: "/").last.map(String.init) ?? ""
        return last.localizedCaseInsensitiveContains("sent")
    }
}
