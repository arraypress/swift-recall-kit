//
//  CallsSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Phone and FaceTime calls, through swift-call-log — for a person only. A
//  call holds no words, but "when did Alex last call?" is the other half of
//  everything between the owner and somebody; a word search skips calls.
//

import CallLog
import Foundation

struct CallsSearcher: RecallSearching {
    let store: CallLogStore
    let source = RecallSource.calls

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard let person else { throw SkipReason("calls hold no words — they are searched for a person") }
        guard query.text == nil else { throw SkipReason("calls hold no words to match") }
        guard !person.phones.isEmpty || !person.emails.isEmpty else {
            throw SkipReason("no phone number or email for \(person.query) in Contacts")
        }
        let calls = try store.calls().filter { call in
            HitMerge.within(call.date, since: query.since, until: query.until)
                && SourceRules.includes(person, any: ([call.address].compactMap { $0 }) + call.participants.flatMap {
                    [$0.address, $0.normalized].compactMap { $0 }
                })
        }
        let hits = calls.sorted { $0.date > $1.date }.prefix(query.limit).map { call in
            let who = call.participants.first.flatMap(\.name) ?? person.names.first ?? call.address
            let line = SourceRules.line(incoming: call.direction == .incoming, missed: call.status == .missed,
                                        facetime: call.service == .facetime, video: call.media == .video,
                                        seconds: call.duration)
            return RecallHit(source: .calls, id: call.id, date: call.date, from: call.direction == .incoming ? who : "me",
                             address: call.address, isFromMe: call.direction == .outgoing, title: who, excerpt: line)
        }
        return (Array(hits), 0)
    }
}
