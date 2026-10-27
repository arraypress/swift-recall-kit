//
//  Recall.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  One search across everything said and written on this Mac: Mail,
//  Messages, WhatsApp, calls, Calendar, Reminders, Notes, Voice Memos,
//  Journal, Freeform and Books highlights.
//  Each source is read through its own library, read-only; one that can't be
//  read (no Full Disk Access, WhatsApp not installed, Calendar refused) is
//  skipped and reported, and the rest still answer.
//

import AgendaKit
import AppleBooks
import AppleFreeform
import AppleJournal
import AppleMail
import AppleMessages
import AppleNotes
import CallLog
import ContactsKit
import EventKit
import Foundation
import VoiceRecordings
import WhatsAppMessages

/// Searches Mail, Messages, WhatsApp, calls, Calendar, Reminders, Notes, Voice Memos, Journal, Freeform and Books at once.
///
/// ```swift
/// let found = try await Recall.search(RecallQuery(text: "boiler", person: "Alex"))
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
    public static func search(_ query: RecallQuery) async throws -> RecallResult {
        let query = normalised(query)
        guard query.text != nil || query.person != nil else { throw RecallError.nothingToFind }

        // People from Contacts: needed to turn a name into addresses, and to
        // name Messages' senders. Without access, both degrade and say so.
        var people: [Person] = []
        var contactsProblem: String?
        let needsContacts = query.sources.contains(.messages) || query.sources.contains(.calls)
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
        open(.calls) { CallsSearcher(store: CallLogStore()) }
        open(.calendar) { CalendarSearcher() }
        open(.reminders) { RemindersSearcher() }
        open(.notes) { NotesSearcher(store: try NoteStore()) }
        open(.memos) { MemosSearcher(store: RecordingStore()) }
        open(.journal) { JournalSearcher(store: try JournalStore()) }
        open(.freeform) { FreeformSearcher(store: try FreeformStore()) }
        open(.books) { BooksSearcher(store: try BooksStore()) }

        let contacts = people.map { PersonMatch.Contact(name: $0.displayName, phones: $0.phoneNumbers.map(\.value),
                                                        emails: $0.emailAddresses.map(\.value)) }
        return try await run(query, searchers: searchers, skipped: skipped, contacts: contacts)
    }

    /// Whether each source can be read on this Mac: each store opened and
    /// closed again — or, for Calendar and Reminders, the access asked
    /// about — nothing searched.
    ///
    /// - Returns: One answer per source, in order.
    public static func availability() -> [RecallAvailability] {
        func granted(_ entity: EKEntityType, _ name: String) throws {
            let access = Agenda.access(to: entity)
            guard access == .authorized else { throw SkipReason("\(name) access is \(access.rawValue)") }
        }
        let openers: [(RecallSource, () throws -> Void)] = [
            (.mail, { _ = try MailStore() }),
            (.messages, { _ = try MessageStore() }),
            (.whatsapp, { _ = try WhatsAppStore() }),
            (.calls, { _ = try CallLogStore().calls() }),
            (.calendar, { try granted(.event, "Calendar") }),
            (.reminders, { try granted(.reminder, "Reminders") }),
            (.notes, { _ = try NoteStore() }),
            (.memos, { _ = try RecordingStore().recordings(readFiles: false) }),
            (.journal, { _ = try JournalStore() }),
            (.freeform, { _ = try FreeformStore() }),
            (.books, { _ = try BooksStore() }),
        ]
        return openers.map { source, open in
            do {
                try open()
                return RecallAvailability(source: source, readable: true)
            } catch let reason as SkipReason {
                return RecallAvailability(source: source, readable: false, reason: reason.text)
            } catch {
                return RecallAvailability(source: source, readable: false, reason: error.localizedDescription)
            }
        }
    }

    /// The search over searchers already open — the part tests drive.
    static func run(_ query: RecallQuery, searchers: [any RecallSearching], skipped opened: [RecallSkip],
                    contacts: [PersonMatch.Contact]) async throws -> RecallResult {
        let query = normalised(query)
        guard query.text != nil || query.person != nil else { throw RecallError.nothingToFind }
        let person = query.person.map { PersonMatch.person($0, contacts: contacts) }
        var lists: [RecallSource: [RecallHit]] = [:]
        var skipped = opened
        var unread = 0
        for searcher in searchers {
            do {
                let found = try await searcher.hits(for: query, person: person)
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
