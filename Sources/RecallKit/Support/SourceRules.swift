//
//  SourceRules.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  The rules the newer sources need, pure: whether a person was on a call
//  or invited to an event, how a call reads as a line, and the stretch of
//  calendar searched when none is given.
//

import ContactsKit
import Foundation

enum SourceRules {

    // MARK: - People

    /// Whether any of `addresses` is one of the person's: phones compared by
    /// number (`+44 7700 900123` is `07700 900123`), emails ignoring case.
    static func includes(_ person: RecallPerson, any addresses: [String]) -> Bool {
        addresses.contains { address in
            address.contains("@")
                ? person.emails.contains { $0.caseInsensitiveCompare(address) == .orderedSame }
                : person.phones.contains { PhoneMatch.same($0, address) }
        }
    }

    /// Whether a person was at an event: an invitee's or the organiser's
    /// email is theirs, or a name holds what was asked or a contact's name.
    static func attends(_ person: RecallPerson, names: [String], emails: [String]) -> Bool {
        if includes(person, any: emails) { return true }
        let wanted = [person.query] + person.names
        return names.contains { name in
            wanted.contains { name.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }

    // MARK: - Calls

    /// A call as a line: "Missed FaceTime video call", "Outgoing call · 12 min".
    static func line(incoming: Bool, missed: Bool, facetime: Bool, video: Bool, seconds: Double) -> String {
        let kind = (facetime ? "FaceTime " : "") + (video ? "video call" : (facetime ? "audio call" : "call"))
        if missed { return "Missed " + kind }
        let way = incoming ? "Incoming " : "Outgoing "
        guard seconds >= 1 else { return way + kind + " · not answered" }
        let minutes = Int((seconds / 60).rounded())
        return way + kind + " · " + (minutes < 1 ? "\(Int(seconds)) s" : "\(minutes) min")
    }

    // MARK: - Calendar

    /// Years back the calendar is searched when no start is given.
    static let calendarYearsBack = 2
    /// Years ahead, when no end is given: "when's the dentist?" is about the future.
    static let calendarYearsAhead = 1

    /// One occurrence of each repeating event: the one nearest `now`, past or
    /// coming — a weekly class would otherwise fill the results 150 times
    /// over three years. Returns the indices kept, in their first order.
    ///
    /// - Parameter series: each occurrence's series key and date.
    static func nearestOfEach(_ series: [(key: String, date: Date)], now: Date = Date()) -> [Int] {
        var best: [String: Int] = [:]
        for (index, item) in series.enumerated() {
            if let kept = best[item.key], abs(series[kept].date.timeIntervalSince(now)) <= abs(item.date.timeIntervalSince(now)) {
                continue
            }
            best[item.key] = index
        }
        return best.values.sorted()
    }

    /// The stretch of calendar searched.
    static func calendarWindow(since: Date?, until: Date?, now: Date = Date(),
                               calendar: Calendar = .current) -> (from: Date, to: Date) {
        let from = since ?? calendar.date(byAdding: .year, value: -calendarYearsBack, to: now)!
        let to = until ?? calendar.date(byAdding: .year, value: calendarYearsAhead, to: now)!
        return (from, to)
    }
}
