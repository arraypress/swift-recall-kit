//
//  BooksSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Books, through swift-apple-books: highlighted passages and the notes
//  written on them, dated when they were made, titled by the book (and its
//  chapter). A passage is an author's words and a note the reader's own;
//  neither has a sender, so a person search skips them.
//

import AppleBooks
import Foundation

struct BooksSearcher: RecallSearching {
    let store: BooksStore
    let source = RecallSource.books

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard person == nil else { throw SkipReason("highlights have no sender") }
        guard let text = query.text else { throw SkipReason("highlights need words to find") }
        let titles = Dictionary(store.books().map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        let hits = store.search(text).compactMap { mark -> RecallHit? in
            let date = mark.created ?? mark.modified ?? .distantPast
            guard HitMerge.within(date, since: query.since, until: query.until) else { return nil }
            let title = [titles[mark.book], mark.chapter].compactMap { $0 }.joined(separator: " · ")
            let words = [mark.text, mark.note].compactMap { $0 }.joined(separator: " — ")
            return RecallHit(source: .books, id: mark.id, date: date, isFromMe: true, title: title.isEmpty ? nil : title,
                             excerpt: Excerpt.around(text, in: words), parent: mark.book)
        }
        return (Array(hits.sorted { $0.date > $1.date }.prefix(query.limit)), 0)
    }
}
