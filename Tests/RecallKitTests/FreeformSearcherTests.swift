//
//  FreeformSearcherTests.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Freeform as a recall source, on a tiny synthetic store with Freeform's
//  tables: an item's words found and dated by its board, the board named and
//  carried as the parent, the stretch of dates kept, and a person search
//  skipped. Everything invented.
//

import AppleFreeform
import Foundation
import SQLite3
import XCTest
@testable import RecallKit

final class FreeformSearcherTests: XCTestCase {

    var folder: URL!

    override func setUpWithError() throws {
        folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recall-freeform-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: folder) }

    /// A record as Freeform writes one: `crdt`, a version, words in nested messages.
    func record(_ words: [String]) -> Data {
        func field(_ number: UInt8, _ bytes: [UInt8]) -> [UInt8] { [number << 3 | 2, UInt8(bytes.count)] + bytes }
        var body: [UInt8] = [0x08, 0x01]
        for word in words { body += field(2, field(3, field(1, Array(word.utf8)))) }
        return Data(Array("crdt".utf8) + [6, 0, 0, 0] + body + field(2, Array("a".utf8)))
    }

    func store() throws -> FreeformStore {
        let url = folder.appendingPathComponent("boards.db")
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
        run("CREATE TABLE boards (board_identifier BLOB, data BLOB, last_activity_time REAL, tombstoned INTEGER)")
        run("CREATE TABLE board_items (item_uuid BLOB, board_identifier BLOB, item_type INTEGER, sub_item_type INTEGER, specific_data BLOB, capsule_data BLOB, tombstoned INTEGER)")
        run("CREATE TABLE assets (asset_uuid BLOB, extension TEXT, tombstone_date REAL)")
        run("CREATE TABLE asset_references (referrer_identifier BLOB, board_identifier BLOB, referrer_asset_name TEXT, asset_uuid BLOB)")
        run("INSERT INTO boards VALUES (?, ?, 800000000, 0)", [Data(repeating: 1, count: 16), record(["Kitchen plan"])])
        run("INSERT INTO board_items VALUES (?, ?, 12, NULL, ?, NULL, 0)",
            [Data(repeating: 2, count: 16), Data(repeating: 1, count: 16), record(["Order the oak worktop"])])
        return try FreeformStore(url: url)
    }

    func testWordsAreFoundDatedByTheirBoardAndAPersonIsSkipped() async throws {
        let searcher = FreeformSearcher(store: try store())
        let hits = try await searcher.hits(for: RecallQuery(text: "worktop"), person: nil).hits
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.title, "Kitchen plan", "the board names the hit")
        XCTAssertEqual(hits.first?.parent, "01010101-0101-0101-0101-010101010101", "the board, to show it")
        XCTAssertEqual(hits.first?.date, Date(timeIntervalSinceReferenceDate: 800_000_000), "the board's last activity")
        XCTAssertNotNil(hits.first?.excerpt.range(of: "oak worktop"))
        let late = try await searcher.hits(for: RecallQuery(text: "worktop", since: Date(timeIntervalSinceReferenceDate: 800_000_001)), person: nil).hits
        XCTAssertTrue(late.isEmpty, "the stretch of dates is kept")
        do {
            _ = try await searcher.hits(for: RecallQuery(text: "worktop"), person: RecallPerson(query: "alex"))
            XCTFail("a person search read the boards")
        } catch let reason as SkipReason { XCTAssertEqual(reason.text, "boards record no author for what is on them") }
    }
}
