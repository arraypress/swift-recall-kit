//
//  JournalSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Apple Journal, through swift-apple-journal: words in an entry's title and
//  body, the places on its maps, and what its recordings and sketches say.
//  Entries are the owner's own writing and have no sender: a person search
//  skips them.
//

import AppleJournal
import Foundation

struct JournalSearcher: RecallSearching {
    let store: JournalStore
    let source = RecallSource.journal

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard person == nil else { throw SkipReason("journal entries have no sender") }
        guard let text = query.text else { throw SkipReason("journal entries need words to find") }
        let hits = store.search(text)
            .filter { HitMerge.within($0.date, since: query.since, until: query.until) }
            .prefix(query.limit)
            .map { entry in
                let extras = entry.attachments.flatMap { $0.places + [$0.transcript].compactMap { $0 } }
                let body = Excerpt.matches(text, in: entry.text) || extras.isEmpty ? entry.text : extras.joined(separator: " · ")
                return RecallHit(source: .journal, id: String(entry.id), date: entry.date, isFromMe: true,
                                 title: entry.title.isEmpty ? nil : entry.title,
                                 excerpt: Excerpt.around(text, in: body.isEmpty ? entry.title : body))
            }
        return (Array(hits), 0)
    }
}
