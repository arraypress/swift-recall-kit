//
//  RemindersSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Reminders, through swift-agenda-kit: words in a reminder's title, notes
//  or link, done ones included ("what did I call that booking?"). Reminders
//  have no sender: a person search skips them.
//

import AgendaKit
import EventKit
import Foundation

struct RemindersSearcher: RecallSearching {
    let source = RecallSource.reminders

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard person == nil else { throw SkipReason("reminders have no sender") }
        guard let text = query.text else { throw SkipReason("reminders need words to find") }
        guard try await CalendarSearcher.access(to: .reminder) else { throw SkipReason("no access to Reminders") }
        let window = SourceRules.calendarWindow(since: nil, until: nil)
        let reminders = try await Agenda.search(text, from: window.from, to: window.to, includeEvents: false,
                                                includeReminders: true).compactMap {
            if case .reminder(let reminder) = $0 { return reminder } else { return nil }
        }
        let hits = reminders.compactMap { reminder -> RecallHit? in
            let date = reminder.dueAt ?? reminder.modifiedAt ?? reminder.createdAt ?? .distantPast
            guard HitMerge.within(date, since: query.since, until: query.until) else { return nil }
            return RecallHit(source: .reminders, id: reminder.id, date: date, isFromMe: true,
                             title: reminder.title + (reminder.isCompleted ? " ✓" : ""),
                             excerpt: Excerpt.around(text, in: reminder.notes.map { reminder.title + " — " + $0 } ?? reminder.title))
        }
        return (hits, 0)
    }
}
