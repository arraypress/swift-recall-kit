//
//  BooksSearcherTests.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Books as a recall source, on tiny synthetic stores with Books' tables:
//  a passage and a note found, titled by the book, dated when made, the
//  stretch of dates kept, and a person search skipped. Everything invented.
//

import AppleBooks
import Foundation
import SQLite3
import XCTest
@testable import RecallKit

final class BooksSearcherTests: XCTestCase {

    var folder: URL!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recall-books-\(UUID().uuidString)")
        for sub in ["BKLibrary", "AEAnnotation"] {
            try FileManager.default.createDirectory(at: folder.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    func run(_ file: String, _ statements: [String]) {
        var db: OpaquePointer?
        sqlite3_open(folder.appendingPathComponent(file).path, &db)
        defer { sqlite3_close(db) }
        for sql in statements { XCTAssertEqual(sqlite3_exec(db, sql, nil, nil, nil), SQLITE_OK, sql) }
    }

    func store() throws -> BooksStore {
        run("BKLibrary/BKLibrary-1.sqlite", [
            "CREATE TABLE ZBKLIBRARYASSET (Z_PK INTEGER PRIMARY KEY, ZASSETID TEXT, ZTITLE TEXT, ZAUTHOR TEXT, ZKIND TEXT, ZGENRE TEXT, ZREADINGPROGRESS REAL, ZISFINISHED INTEGER, ZISSAMPLE INTEGER, ZLASTOPENDATE REAL, ZDATEFINISHED REAL, ZPATH TEXT, ZCONTENTTYPE INTEGER, ZISHIDDEN INTEGER, ZSORTTITLE TEXT, ZSTATE INTEGER, ZSERIESCONTAINER INTEGER)",
            "CREATE TABLE ZBKCOLLECTION (Z_PK INTEGER PRIMARY KEY, ZCOLLECTIONID TEXT, ZTITLE TEXT, ZDELETEDFLAG INTEGER, ZHIDDEN INTEGER)",
            "CREATE TABLE ZBKCOLLECTIONMEMBER (Z_PK INTEGER PRIMARY KEY, ZASSET INTEGER, ZCOLLECTION INTEGER)",
            "INSERT INTO ZBKLIBRARYASSET VALUES (1, '100', 'The Keeper', 'Ada Moss', 'ebook', NULL, 0.2, 0, 0, 800000000, NULL, NULL, 1, 0, 'keeper', 1, NULL)",
        ])
        run("AEAnnotation/AEAnnotation_local.sqlite", [
            "CREATE TABLE ZAEANNOTATION (Z_PK INTEGER PRIMARY KEY, ZANNOTATIONUUID TEXT, ZANNOTATIONASSETID TEXT, ZANNOTATIONTYPE INTEGER, ZANNOTATIONSTYLE INTEGER, ZANNOTATIONISUNDERLINE INTEGER, ZANNOTATIONSELECTEDTEXT TEXT, ZANNOTATIONREPRESENTATIVETEXT TEXT, ZANNOTATIONNOTE TEXT, ZANNOTATIONLOCATION TEXT, ZANNOTATIONCREATIONDATE REAL, ZANNOTATIONMODIFICATIONDATE REAL, ZANNOTATIONDELETED INTEGER)",
            "INSERT INTO ZAEANNOTATION VALUES (1, 'a', '100', 2, 3, 0, 'the lamp was lit at dusk', NULL, 'Use this in the talk', 'epubcfi(/6/2!/4/2/1,:0,:5)', 800000100, NULL, 0)",
            "INSERT INTO ZAEANNOTATION VALUES (2, 'b', '100', 2, 1, 0, 'salt on the wind', NULL, NULL, 'epubcfi(/6/2!/4/4/1,:0,:5)', 790000000, NULL, 0)",
        ])
        return try BooksStore(folder: folder)
    }

    func testPassagesAndNotesAreFoundAndAPersonIsSkipped() async throws {
        let searcher = BooksSearcher(store: try store())
        let lamp = try await searcher.hits(for: RecallQuery(text: "lamp"), person: nil).hits
        XCTAssertEqual(lamp.map(\.id), ["a"])
        XCTAssertEqual(lamp.first?.title, "The Keeper", "titled by the book")
        XCTAssertEqual(lamp.first?.parent, "100", "the book, to show it")
        XCTAssertEqual(lamp.first?.date, Date(timeIntervalSinceReferenceDate: 800_000_100), "when it was made")
        let note = try await searcher.hits(for: RecallQuery(text: "talk"), person: nil).hits
        XCTAssertNotNil(note.first?.excerpt.range(of: "Use this in the talk"), "a note is searched and shown")
        let early = try await searcher.hits(for: RecallQuery(text: "salt", until: Date(timeIntervalSinceReferenceDate: 789_999_999)), person: nil).hits
        XCTAssertTrue(early.isEmpty, "the stretch of dates is kept")
        do {
            _ = try await searcher.hits(for: RecallQuery(text: "lamp"), person: RecallPerson(query: "alex"))
            XCTFail("a person search read the highlights")
        } catch let reason as SkipReason { XCTAssertEqual(reason.text, "highlights have no sender") }
    }
}
