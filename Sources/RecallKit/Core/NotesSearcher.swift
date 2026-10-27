//
//  NotesSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Notes, through swift-apple-notes. Its index matches a note's title and
//  its opening lines; with `bodies`, the newest `bodyBudget` notes are
//  decoded whole and searched too. Notes have no sender: a person search
//  skips them, and says so.
//

import AppleNotes
import Foundation

struct NotesSearcher: RecallSearching {
    let store: NoteStore
    let source = RecallSource.notes

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard person == nil else { throw SkipReason("notes have no sender") }
        guard let text = query.text else { throw SkipReason("notes need words to find") }
        var found = try store.search(text)
            .filter { HitMerge.within(NotesSearcher.date(of: $0), since: query.since, until: query.until) }
            .prefix(query.limit)
            .map { hit($0, excerpt: Excerpt.around(text, in: $0.snippet ?? $0.title)) }
        var unread = 0
        if query.bodies {
            let matched = Set(found.map(\.id))
            for listed in try store.notes(limit: query.bodyBudget)
            where !matched.contains(String(listed.id)) && HitMerge.within(NotesSearcher.date(of: listed), since: query.since, until: query.until) {
                guard let note = try? store.note(id: listed.id) else { unread += 1; continue }
                if Excerpt.matches(text, in: note.text) { found.append(hit(note, excerpt: Excerpt.around(text, in: note.text))) }
            }
        }
        return (Array(found), unread)
    }

    /// When a note was last changed, or made.
    static func date(of note: Note) -> Date { note.modified ?? note.created ?? .distantPast }

    private func hit(_ note: Note, excerpt: String) -> RecallHit {
        RecallHit(source: .notes, id: String(note.id), date: NotesSearcher.date(of: note), isFromMe: true,
                  title: note.title, excerpt: excerpt)
    }
}
