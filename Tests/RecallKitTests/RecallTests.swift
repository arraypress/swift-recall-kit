//
//  RecallTests.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  RecallKit's rules with no store opened: excerpts, people, merging, and a
//  whole search over stand-in sources — nobody's mail or messages are read.
//  Every name, address and message here is invented.
//

import Foundation
import XCTest
@testable import RecallKit

/// A source that answers with what it was given, or skips.
struct FakeSource: RecallSearching {
    let source: RecallSource
    var hits: [RecallHit] = []
    var skip: String?
    var unread = 0
    /// What it was asked, for checking.
    final class Seen: @unchecked Sendable { var person: RecallPerson?; var query: RecallQuery? }
    let seen = Seen()

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        seen.person = person
        seen.query = query
        if let skip { throw SkipReason(skip) }
        return (hits, unread)
    }
}

final class RecallTests: XCTestCase {

    func day(_ n: Double) -> Date { Date(timeIntervalSince1970: 1_790_000_000 + n * 86_400) }

    func hit(_ source: RecallSource, _ id: Int64, _ day: Double) -> RecallHit {
        RecallHit(source: source, id: String(id), date: self.day(day), excerpt: "x")
    }

    let contacts = [
        PersonMatch.Contact(name: "Alex Rivera", phones: ["+44 7700 900123"], emails: ["alex@example.com"]),
        PersonMatch.Contact(name: "Alexis Chen", phones: [], emails: ["achen@example.org", "ALEX@example.com"]),
        PersonMatch.Contact(name: "Sam Ortiz", phones: ["07700 900456"], emails: []),
    ]

    // MARK: - Excerpts

    func testAnExcerptCentresOnTheMatch() {
        let long = String(repeating: "lorem ipsum ", count: 30) + "the boiler needs a service " + String(repeating: "dolor sit ", count: 30)
        let excerpt = Excerpt.around("BOILER", in: long, width: 80)
        XCTAssertNotNil(excerpt.range(of: "boiler"), excerpt)
        XCTAssert(excerpt.hasPrefix("…") && excerpt.hasSuffix("…"), excerpt)
        XCTAssertLessThanOrEqual(excerpt.count, 82)
        XCTAssertFalse(excerpt.contains("  "))
    }

    func testAShortTextIsWholeOnOneLine() {
        XCTAssertEqual(Excerpt.around("x", in: "Call me\n\nabout   the flat"), "Call me about the flat")
    }

    func testWithoutAMatchTheExcerptIsTheStart() {
        let text = String(repeating: "word ", count: 100)
        let excerpt = Excerpt.around("absent", in: text, width: 40)
        XCTAssert(excerpt.hasPrefix("word") && excerpt.hasSuffix("…"), excerpt)
    }

    func testMatchingIgnoresCaseAndAccents() {
        XCTAssert(Excerpt.matches("cafe", in: "Meet at the Café"))
        XCTAssertFalse(Excerpt.matches("tea", in: "Meet at the Café"))
    }

    // MARK: - People

    func testANameIsEveryAddressOfTheContactsItMatches() {
        let person = PersonMatch.person("alex", contacts: contacts)
        XCTAssertEqual(person.names, ["Alex Rivera", "Alexis Chen"])
        XCTAssertEqual(person.phones, ["+44 7700 900123"])
        XCTAssertEqual(person.emails, ["alex@example.com", "achen@example.org"], "the same address in two cases, once")
    }

    func testAnAddressIsItself() {
        XCTAssertEqual(PersonMatch.person("sam@example.net", contacts: contacts).emails, ["sam@example.net"])
        XCTAssertEqual(PersonMatch.person("+44 (0)7700-900456", contacts: contacts).phones, ["+44 (0)7700-900456"])
        XCTAssertEqual(PersonMatch.person("Nobody", contacts: contacts), RecallPerson(query: "Nobody"))
    }

    func testWhatCountsAsAnAddress() {
        XCTAssert(PersonMatch.isAddress("a@b.co"))
        XCTAssert(PersonMatch.isAddress("07700 900456"))
        XCTAssertFalse(PersonMatch.isAddress("Sam"))
        XCTAssertFalse(PersonMatch.isAddress("Flat 4"), "a short number in a name is not a phone")
        XCTAssertFalse(PersonMatch.isAddress("sam @ work"))
        XCTAssertFalse(PersonMatch.isAddress("4567"), "too few digits for a phone number")
    }

    // MARK: - Merging

    func testHitsMergeNewestFirstToTheLimit() {
        let merged = HitMerge.merged([.mail: [hit(.mail, 1, 3), hit(.mail, 2, 1)],
                                      .messages: [hit(.messages, 7, 2), hit(.messages, 7, 2), hit(.messages, 8, 5)]], limit: 3)
        XCTAssertEqual(merged.hits.map(\.id), ["8", "1", "7"])
        XCTAssertEqual(merged.found, [.mail: 2, .messages: 2], "a row found twice counts once")
    }

    func testTiesHaveOneOrder() {
        // Twenty-four hits at one moment, given in the worst order.
        var lists: [RecallSource: [RecallHit]] = [:]
        for source in RecallSource.allCases.reversed() { lists[source] = (1...6).map { hit(source, Int64($0), 1) } }
        let order = HitMerge.merged(lists, limit: 100).hits.map { "\($0.source.rawValue)\($0.id)" }
        let wanted = RecallSource.allCases.flatMap { source in (1...6).reversed().map { "\(source.rawValue)\($0)" } }
        XCTAssertEqual(order, wanted, "by source, then newest row")
    }

    func testWithin() {
        XCTAssert(HitMerge.within(day(2), since: day(1), until: day(3)))
        XCTAssertFalse(HitMerge.within(day(4), since: day(1), until: day(3)))
        XCTAssertFalse(HitMerge.within(day(0), since: day(1), until: nil))
    }

    // MARK: - A whole search

    func testASearchReportsWhatItSkippedAndWhy() async throws {
        let mail = FakeSource(source: .mail, hits: [hit(.mail, 1, 2)], unread: 4)
        let notes = FakeSource(source: .notes, skip: "notes have no sender")
        let messages = FakeSource(source: .messages, skip: "no access")
        let result = try await Recall.run(RecallQuery(text: "flat", person: "Alex"), searchers: [mail, notes, messages],
                                    skipped: [RecallSkip(source: .whatsapp, reason: "not installed")], contacts: contacts)
        XCTAssertEqual(result.hits.map(\.id), ["1"])
        XCTAssertEqual(result.skipped, [RecallSkip(source: .messages, reason: "no access"),
                                        RecallSkip(source: .whatsapp, reason: "not installed"),
                                        RecallSkip(source: .notes, reason: "notes have no sender")], "in source order")
        XCTAssertEqual(result.unreadBodies, 4)
        XCTAssertEqual(result.person?.emails, ["alex@example.com", "achen@example.org"])
        XCTAssertEqual(mail.seen.person?.names, ["Alex Rivera", "Alexis Chen"], "the source is handed the person resolved")
    }

    func testNothingToFindAndNothingSearchedAreErrors() async {
        do {
            _ = try await Recall.run(RecallQuery(text: "  ", person: ""), searchers: [], skipped: [], contacts: [])
            XCTFail("an empty query ran")
        } catch { XCTAssertEqual(error as? RecallError, .nothingToFind) }
        let skipping = FakeSource(source: .mail, skip: "no access")
        do {
            _ = try await Recall.run(RecallQuery(text: "x"), searchers: [skipping], skipped: [], contacts: [])
            XCTFail("a search with nothing readable answered")
        } catch { XCTAssertEqual(error as? RecallError, .nothingSearched([RecallSkip(source: .mail, reason: "no access")])) }
    }

    // MARK: - Calls, Calendar

    let alex = RecallPerson(query: "alex", names: ["Alex Rivera"], phones: ["+44 7700 900123"], emails: ["alex@example.com"])

    func testAPersonsAddressesMatchByNumberAndIgnoringCase() {
        XCTAssert(SourceRules.includes(alex, any: ["07700 900123"]), "the same number written another way")
        XCTAssert(SourceRules.includes(alex, any: ["ALEX@example.com"]))
        XCTAssertFalse(SourceRules.includes(alex, any: ["07700 900999", "sam@example.com"]))
    }

    func testAnEventIsAPersonsWhenTheyWereInvitedOrOrganisedIt() {
        XCTAssert(SourceRules.attends(alex, names: ["Pat"], emails: ["alex@example.com"]))
        XCTAssert(SourceRules.attends(alex, names: ["Alex Rivera (Lettings)"], emails: []))
        XCTAssert(SourceRules.attends(RecallPerson(query: "rivera"), names: ["Alex Rivera"], emails: []), "what was typed")
        XCTAssertFalse(SourceRules.attends(alex, names: ["Sam Ortiz"], emails: ["sam@example.com"]))
    }

    func testACallReadsAsALine() {
        XCTAssertEqual(SourceRules.line(incoming: true, missed: true, facetime: true, video: true, seconds: 0), "Missed FaceTime video call")
        XCTAssertEqual(SourceRules.line(incoming: false, missed: false, facetime: false, video: false, seconds: 700), "Outgoing call · 12 min")
        XCTAssertEqual(SourceRules.line(incoming: true, missed: false, facetime: true, video: false, seconds: 25), "Incoming FaceTime audio call · 25 s")
        XCTAssertEqual(SourceRules.line(incoming: false, missed: false, facetime: false, video: false, seconds: 0), "Outgoing call · not answered")
    }

    func testARepeatingEventIsKeptOnceNearestToday() {
        let now = day(0)
        let series = [("gym", day(-14)), ("gym", day(-7)), ("dentist", day(30)), ("gym", day(7)), ("gym", day(-2)), ("gym", day(1))]
        XCTAssertEqual(SourceRules.nearestOfEach(series.map { (key: $0.0, date: $0.1) }, now: now), [2, 5],
                       "the dentist, and the gym tomorrow — not four gyms")
    }

    func testTheCalendarLooksBackAndAhead() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = day(0)
        let window = SourceRules.calendarWindow(since: nil, until: nil, now: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year], from: window.from, to: now).year, 2)
        XCTAssertEqual(calendar.dateComponents([.year], from: now, to: window.to).year, 1, "the future counts: when is the dentist?")
        XCTAssertEqual(SourceRules.calendarWindow(since: day(-5), until: day(5), now: now).from, day(-5))
    }

    func testBlankWordsAreNoWords() async throws {
        let mail = FakeSource(source: .mail)
        _ = try await Recall.run(RecallQuery(text: "  ", person: "sam@example.net"), searchers: [mail], skipped: [], contacts: [])
        XCTAssertNil(mail.seen.query?.text)
    }

    // MARK: - Source rules

    func testMailSendersComeFromThePerson() {
        XCTAssertEqual(MailSearcher.senders(for: nil), [nil])
        XCTAssertEqual(MailSearcher.senders(for: RecallPerson(query: "alex", names: ["Alex Rivera"], emails: ["a@x.co"])), ["a@x.co"])
        XCTAssertEqual(MailSearcher.senders(for: RecallPerson(query: "sam", names: ["Sam Ortiz"])), ["Sam Ortiz"])
        XCTAssertEqual(MailSearcher.senders(for: RecallPerson(query: "Pat")), ["Pat"], "nobody in Contacts: what was typed")
    }

    func testSentMailboxes() {
        XCTAssert(MailSearcher.isSent("imap://user@imap.example.com/Sent%20Messages"))
        XCTAssert(MailSearcher.isSent("ews://abc/Sent Items"))
        XCTAssertFalse(MailSearcher.isSent("imap://sent.example.com/INBOX"), "the server's name is not the mailbox")
    }
}
