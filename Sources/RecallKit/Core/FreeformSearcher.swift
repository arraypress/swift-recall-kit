//
//  FreeformSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Freeform, through swift-apple-freeform: what is written on boards — text
//  boxes, sticky notes, table cells, links. An item has no date of its own,
//  so it carries its board's last activity; boards record no author per
//  item, so a person search skips them.
//

import AppleFreeform
import Foundation

struct FreeformSearcher: RecallSearching {
    let store: FreeformStore
    let source = RecallSource.freeform

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard person == nil else { throw SkipReason("boards record no author for what is on them") }
        guard let text = query.text else { throw SkipReason("boards need words to find") }
        let boards = Dictionary(store.boards().map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let hits = store.search(text).compactMap { item -> RecallHit? in
            guard let board = boards[item.board] else { return nil }
            let date = board.lastActivity ?? .distantPast
            guard HitMerge.within(date, since: query.since, until: query.until) else { return nil }
            let words = (item.text + [item.url].compactMap { $0 }).joined(separator: " · ")
            return RecallHit(source: .freeform, id: item.id, date: date, isFromMe: true, title: board.name,
                             excerpt: Excerpt.around(text, in: words), parent: board.id)
        }
        return (Array(hits.prefix(query.limit)), 0)
    }
}
