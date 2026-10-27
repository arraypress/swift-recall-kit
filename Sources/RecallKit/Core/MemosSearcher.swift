//
//  MemosSearcher.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  Voice Memos, through swift-voice-recordings: words in a recording's
//  title, and in what was said — Apple's own transcript kept inside the
//  recording, or one `memos` saved — with the moment each was said.
//  Recordings have no sender: a person search skips them.
//

import Foundation
import VoiceRecordings

struct MemosSearcher: RecallSearching {
    let store: RecordingStore
    let source = RecallSource.memos

    func hits(for query: RecallQuery, person: RecallPerson?) async throws -> (hits: [RecallHit], unreadBodies: Int) {
        guard person == nil else { throw SkipReason("recordings have no sender") }
        guard let text = query.text else { throw SkipReason("recordings need words to find") }
        let recordings = try store.recordings(readFiles: false).filter {
            $0.deleted == nil && HitMerge.within($0.date, since: query.since, until: query.until)
        }
        var transcripts: [String: Transcript] = [:]
        for recording in recordings {
            let transcript = (recording.hasTranscript ? try? store.voiceMemosTranscript(for: recording) : nil)
                ?? store.savedTranscript(for: recording)
            if let transcript { transcripts[recording.id] = transcript }
        }
        let hits = RecordingSearch.matches(text, in: recordings, transcripts: transcripts).map { match in
            RecallHit(source: .memos, id: match.recordingID, date: match.date, isFromMe: true, title: match.title,
                      excerpt: match.snippet, at: match.at)
        }
        return (hits, 0)
    }
}
