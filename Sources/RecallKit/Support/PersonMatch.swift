//
//  PersonMatch.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  A person query to the addresses to search: an address is itself; a name
//  is every phone and email of the contacts it matches. Pure — the contacts
//  come in as values.
//

import Foundation

enum PersonMatch {

    /// A contact as this needs it.
    struct Contact: Sendable, Equatable {
        let name: String
        let phones: [String]
        let emails: [String]
    }

    /// Whether `text` is a phone number or an email address rather than a name.
    static func isAddress(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("@") { return !trimmed.contains(" ") }
        let digits = trimmed.filter(\.isNumber)
        let allowed = Set("+0123456789 ()-.")
        return digits.count >= 6 && trimmed.allSatisfy { allowed.contains($0) }
    }

    /// The person `query` is: itself when it is an address, else the
    /// contacts it names — every address of each, duplicates out.
    static func person(_ query: String, contacts: [Contact]) -> RecallPerson {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !isAddress(trimmed) else {
            return trimmed.contains("@") ? RecallPerson(query: trimmed, emails: [trimmed])
                                         : RecallPerson(query: trimmed, phones: [trimmed])
        }
        let matched = contacts.filter { $0.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return RecallPerson(query: trimmed, names: unique(matched.map(\.name)),
                            phones: unique(matched.flatMap(\.phones)), emails: unique(matched.flatMap(\.emails)))
    }

    /// Values in their first order, each once, ignoring case.
    static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0.lowercased()).inserted }
    }
}
