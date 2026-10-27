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
    /// Apple Notes: titles and the start of each note, and optionally whole notes.
    case notes

    /// The sources in a fixed order, so results and reports read the same every time.
    public static func < (lhs: RecallSource, rhs: RecallSource) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
