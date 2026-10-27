//
//  Recall.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  One search across everything said and written on this Mac: Mail,
//  Messages, WhatsApp and Notes. Each source is read through its own
//  library, read-only; one that can't be read (no Full Disk Access, WhatsApp
//  not installed) is skipped and reported, and the rest still answer.
//

import AppleMail
import AppleMessages
import AppleNotes
import ContactsKit
import Foundation
import WhatsAppMessages

/// Searches Mail, Messages, WhatsApp and Notes at once.
///
/// ```swift
/// let found = try Recall.search(RecallQuery(text: "boiler", person: "Alex"))
/// for hit in found.hits { print(hit.date, hit.source, hit.from ?? "", hit.excerpt) }
/// found.skipped   // [notes: notes have no sender]
/// ```
public enum Recall {

    /// Every source the query names, searched; their hits merged newest first.
    ///
    /// - Parameter query: What to find.
    /// - Returns: The hits, each source's count, and the sources skipped with why.
    /// - Throws: ``RecallError/nothingToFind`` without words or a person;
    ///   ``RecallError/nothingSearched(_:)`` when no source could be read.
    public static func search(_ query: RecallQuery) throws -> RecallResult {
        let query = normalised(query)
        guard query.text != nil || query.person != nil else { throw RecallError.nothingToFind }

        // People from Contacts: needed to turn a name into addresses, and to
        // name Messages' senders. Without access, both degrade and say so.
        var people: [Person] = []
        var contactsProblem: String?
        let needsContacts = query.sources.contains(.messages)
            || (query.person.map { !PersonMatch.isAddress($0) } ?? false)
        if needsContacts {
            do { people = try ContactStore().all() } catch { contactsProblem = error.localizedDescription }
        }

        var searchers: [any RecallSearching] = []
        var skipped: [RecallSkip] = []
        func open(_ source: RecallSource, _ make: () throws -> any RecallSearching) {
            guard query.sources.contains(source) else { return }
            do { searchers.append(try make()) } catch {
                skipped.append(RecallSkip(source: source, reason: error.localizedDescription))
            }
        }
        open(.mail) { MailSearcher(store: try MailStore()) }
        open(.messages) {
            MessagesSearcher(store: try MessageStore(), names: contactsProblem == nil ? ContactNames(people) : nil,
                             contactsProblem: contactsProblem)
        }
        open(.whatsapp) { WhatsAppSearcher(store: try WhatsAppStore()) }
        open(.notes) { NotesSearcher(store: try NoteStore()) }

        let contacts = people.map { PersonMatch.Contact(name: $0.displayName, phones: $0.phoneNumbers.map(\.value),
                                                        emails: $0.emailAddresses.map(\.value)) }
        return try run(query, searchers: searchers, skipped: skipped, contacts: contacts)
    }

    /// Whether each source can be read on this Mac: each store opened and
    /// closed again, nothing searched.
    ///
    /// - Returns: One answer per source, in order.
    public static func availability() -> [RecallAvailability] {
        let openers: [(RecallSource, () throws -> Void)] = [
            (.mail, { _ = try MailStore() }),
            (.messages, { _ = try MessageStore() }),
            (.whatsapp, { _ = try WhatsAppStore() }),
            (.notes, { _ = try NoteStore() }),
        ]
        return openers.map { source, open in
            do {
                try open()
                return RecallAvailability(source: source, readable: true)
            } catch {
                return RecallAvailability(source: source, readable: false, reason: error.localizedDescription)
            }
        }
    }

    /// The search over searchers already open — the part tests drive.
    static func run(_ query: RecallQuery, searchers: [any RecallSearching], skipped opened: [RecallSkip],
                    contacts: [PersonMatch.Contact]) throws -> RecallResult {
        let query = normalised(query)
        guard query.text != nil || query.person != nil else { throw RecallError.nothingToFind }
        let person = query.person.map { PersonMatch.person($0, contacts: contacts) }
        var lists: [RecallSource: [RecallHit]] = [:]
        var skipped = opened
        var unread = 0
        for searcher in searchers {
            do {
                let found = try searcher.hits(for: query, person: person)
                lists[searcher.source] = found.hits
                unread += found.unreadBodies
            } catch let reason as SkipReason {
                skipped.append(RecallSkip(source: searcher.source, reason: reason.text))
            } catch {
                skipped.append(RecallSkip(source: searcher.source, reason: error.localizedDescription))
            }
        }
        guard !lists.isEmpty else { throw RecallError.nothingSearched(skipped.sorted { $0.source < $1.source }) }
        let merged = HitMerge.merged(lists, limit: query.limit)
        return RecallResult(hits: merged.hits, found: merged.found, skipped: skipped.sorted { $0.source < $1.source },
                            person: person, unreadBodies: unread)
    }

    /// A query with blank text and person treated as absent.
    static func normalised(_ query: RecallQuery) -> RecallQuery {
        var query = query
        query.text = query.text?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        query.person = query.person?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return query
    }
}
