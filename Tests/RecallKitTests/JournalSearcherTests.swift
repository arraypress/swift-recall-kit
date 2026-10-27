//
//  JournalSearcherTests.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Journal as a recall source, on a tiny synthetic store with Journal's
//  tables: words found in an entry's body and in its map's places, the
//  stretch of dates kept, and a person search skipped. Everything invented.
//

import AppKit
import AppleJournal
import Foundation
import SQLite3
import XCTest
@testable import RecallKit

final class JournalSearcherTests: XCTestCase {

    var folder: URL!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recall-journal-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    func store() throws -> JournalStore {
        func rtf(_ s: String) throws -> Data {
            let text = NSAttributedString(string: s)
            return try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        }
        let url = folder.appendingPathComponent("moments.sqlite")
        var db: OpaquePointer?
        sqlite3_open(url.path, &db)
        defer { sqlite3_close(db) }
        func run(_ sql: String, _ blobs: [Data] = []) {
            var statement: OpaquePointer?
            sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            for (i, blob) in blobs.enumerated() {
                _ = blob.withUnsafeBytes { sqlite3_bind_blob(statement, Int32(i + 1), $0.baseAddress, Int32(blob.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            }
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE, sql)
            sqlite3_finalize(statement)
        }
        run("CREATE TABLE ZJOURNALMO (Z_PK INTEGER PRIMARY KEY, ZSORTCATEGORY INTEGER, ZSORTORDER INTEGER, ZUSERDELETED INTEGER, ZMERGEABLEATTRIBUTES BLOB)")
        run("CREATE TABLE ZJOURNALENTRYMO (Z_PK INTEGER PRIMARY KEY, ZID BLOB, ZTITLE BLOB, ZTEXT BLOB, ZENTRYDATE REAL, ZCREATEDDATE REAL, ZUPDATEDDATE REAL, ZISDRAFT INTEGER, ZFLAGGED INTEGER, ZRECENTLYDELETED INTEGER, ZISFULLYREMOVED INTEGER)")
        run("CREATE TABLE Z_5JOURNALS (Z_5ENTRIES INTEGER, Z_6JOURNALS INTEGER)")
        run("CREATE TABLE ZJOURNALENTRYASSETMO (Z_PK INTEGER PRIMARY KEY, ZENTRY INTEGER, ZID BLOB, ZASSETTYPE TEXT, ZSOURCE TEXT, ZCREATEDDATE REAL, ZASSETMETADATA BLOB, ZISFULLYREMOVED INTEGER, ZISHIDDEN INTEGER)")
        run("CREATE TABLE ZJOURNALENTRYASSETFILEATTACHMENTMO (Z_PK INTEGER PRIMARY KEY, ZASSET INTEGER, ZINDEX INTEGER, ZFILEPATH TEXT)")
        run("INSERT INTO ZJOURNALENTRYMO VALUES (1, ?, ?, ?, 800000000, 800000000, NULL, 0, 0, 0, 0)",
            [Data(repeating: 1, count: 16), try rtf("Boiler day"), try rtf("The engineer serviced the boiler at last.")])
        run("INSERT INTO ZJOURNALENTRYMO VALUES (2, ?, ?, ?, 790000000, 790000000, NULL, 0, 0, 0, 0)",
            [Data(repeating: 2, count: 16), try rtf("Walk"), try rtf("A long walk.")])
        run("INSERT INTO ZJOURNALENTRYASSETMO VALUES (10, 2, ?, 'multiPinMap', 'locationPicker', NULL, ?, 0, 0)",
            [Data(repeating: 3, count: 16), Data([1]) + Data(#"{"visitsData":[{"placeName":"Harbour Café"}]}"#.utf8)])
        return try JournalStore(url: url)
    }

    func testWordsAndPlacesAreFoundAndAPersonIsSkipped() async throws {
        let searcher = JournalSearcher(store: try store())
        let boiler = try await searcher.hits(for: RecallQuery(text: "boiler"), person: nil).hits
        XCTAssertEqual(boiler.map(\.id), ["1"])
        XCTAssertEqual(boiler.first?.title, "Boiler day")
        XCTAssertNotNil(boiler.first?.excerpt.range(of: "serviced the boiler"))
        XCTAssertEqual(boiler.first?.isFromMe, true, "the owner's own writing")
        let place = try await searcher.hits(for: RecallQuery(text: "harbour"), person: nil).hits
        XCTAssertEqual(place.map(\.id), ["2"])
        XCTAssertEqual(place.first?.excerpt, "Harbour Café", "the place the words were found in, not the unrelated body")
        let late = try await searcher.hits(for: RecallQuery(text: "boiler", since: Date(timeIntervalSinceReferenceDate: 800_000_001)), person: nil).hits
        XCTAssertTrue(late.isEmpty, "the stretch of dates is kept")
        do {
            _ = try await searcher.hits(for: RecallQuery(text: "boiler"), person: RecallPerson(query: "alex"))
            XCTFail("a person search read the journal")
        } catch let reason as SkipReason { XCTAssertEqual(reason.text, "journal entries have no sender") }
    }
}
