//
//  RecallSource.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where something said or written is searched.
public enum RecallSource: String, Sendable, Codable, CaseIterable, Hashable, Comparable {
    /// Apple Mail's index: subjects and senders, and optionally the bodies on this Mac.
    case mail
    /// Messages: iMessage and SMS.
    case messages
    /// WhatsApp's Mac app.
    case whatsapp
    /// Phone and FaceTime calls — for a person only: a call holds no words.
    case calls
    /// Calendar events: titles, places, notes, and who was invited.
    case calendar
    /// Reminders, done or not: titles and notes.
    case reminders
    /// Apple Notes: titles and the start of each note, and optionally whole notes.
    case notes
    /// Voice Memos: titles, and what was said where Apple transcribed it.
    case memos
    /// Apple Journal: entries' titles and words, map places, recorded and handwritten words.
    case journal
    /// Freeform: what is written on boards — text, sticky notes, table cells, links.
    case freeform

    /// The sources in a fixed order, so results and reports read the same every time.
    public static func < (lhs: RecallSource, rhs: RecallSource) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
