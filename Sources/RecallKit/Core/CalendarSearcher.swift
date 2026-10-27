//
//  CalendarSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Calendar events, through swift-agenda-kit (EventKit): words in an
//  event's title, place, notes or link; a person by the people invited and
//  the organiser. EventKit has no text search, so a stretch is fetched and
//  filtered — two years back and one ahead unless the query says.
//

import AgendaKit
import EventKit
import Foundation

struct CalendarSearcher: RecallSearching {
    let source = RecallSource.calendar

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard try await CalendarSearcher.access(to: .event) else { throw SkipReason("no access to Calendar") }
        let window = SourceRules.calendarWindow(since: query.since, until: query.until)
        var events: [AgendaEvent]
        if let text = query.text {
            events = try await Agenda.search(text, from: window.from, to: window.to, includeEvents: true,
                                             includeReminders: false).compactMap {
                if case .event(let event) = $0 { return event } else { return nil }
            }
        } else {
            events = try Agenda.events(from: window.from, to: window.to)
        }
        if let person {
            events = events.filter { event in
                SourceRules.attends(person, names: event.attendees.map(\.name) + [event.organizer].compactMap { $0 },
                                    emails: event.attendees.compactMap(\.email))
            }
        }
        let kept = SourceRules.nearestOfEach(events.map { ($0.calendarItemId ?? $0.id, $0.startsAt) })
        let hits = kept.map { events[$0] }.map { event in
            let detail = [event.location, event.notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
            let excerpt = Excerpt.around(query.text, in: detail.isEmpty ? event.title : detail)
            return RecallHit(source: .calendar, id: event.id, date: event.startsAt, from: event.organizer,
                             title: event.title, excerpt: excerpt + (event.isRecurring ? " (repeats)" : ""))
        }
        return (hits, 0)
    }

    /// Whether Calendar or Reminders can be read, asking once if never asked.
    static func access(to entity: EKEntityType) async throws -> Bool {
        switch Agenda.access(to: entity) {
        case .authorized: return true
        case .notDetermined: return try await Agenda.requestAccess(to: entity) == .authorized
        default: return false
        }
    }
}
