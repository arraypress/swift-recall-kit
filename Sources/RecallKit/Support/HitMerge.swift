//
//  HitMerge.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Every source's hits as one list: duplicates out (a person known by two
//  addresses is searched twice), newest first, cut to the limit, with how
//  many each source matched before the cut. Pure.
//

import Foundation

enum HitMerge {

    /// The merged hits and each source's count.
    static func merged(_ lists: [RecallSource: [RecallHit]], limit: Int) -> (hits: [RecallHit], found: [RecallSource: Int]) {
        var found: [RecallSource: Int] = [:]
        var all: [RecallHit] = []
        for (source, hits) in lists {
            let unique = deduplicated(hits)
            found[source] = unique.count
            all += unique
        }
        // Newest first; a tie by source, then row, so the order never wobbles.
        all.sort { ($0.date, $1.source, $0.id) > ($1.date, $0.source, $1.id) }
        return (Array(all.prefix(max(0, limit))), found)
    }

    /// Hits with each row once, the first kept.
    static func deduplicated(_ hits: [RecallHit]) -> [RecallHit] {
        var seen: Set<Int64> = []
        return hits.filter { seen.insert($0.id).inserted }
    }

    /// Whether a date is inside a query's stretch.
    static func within(_ date: Date, since: Date?, until: Date?) -> Bool {
        (since.map { date >= $0 } ?? true) && (until.map { date <= $0 } ?? true)
    }
}
