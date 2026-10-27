//
//  Excerpt.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//
//  The words around a match: enough to tell which message it was without
//  opening it. Pure — text in, a line out.
//

import Foundation

enum Excerpt {

    /// The text around the first match of `term`, about `width` characters
    /// on one line, cut at word edges with "…" where it was cut. With no term,
    /// or none found, the start of the text.
    static func around(_ term: String?, in text: String, width: Int = 160) -> String {
        let flat = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard flat.count > width else { return flat }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        guard let term, !term.isEmpty, let match = flat.range(of: term, options: options) else {
            return cut(flat, from: flat.startIndex, width: width)
        }
        // A third of the room before the match, the rest after it.
        let before = width / 3
        let start = flat.index(match.lowerBound, offsetBy: -before, limitedBy: flat.startIndex) ?? flat.startIndex
        return cut(flat, from: start, width: width)
    }

    /// `width` characters from `start`, moved to word edges, "…" where cut.
    private static func cut(_ text: String, from start: String.Index, width: Int) -> String {
        var lower = start
        if lower > text.startIndex, let space = text[lower...].firstIndex(of: " ") { lower = text.index(after: space) }
        let end = text.index(lower, offsetBy: width, limitedBy: text.endIndex) ?? text.endIndex
        var upper = end
        if upper < text.endIndex, let space = text[lower..<upper].lastIndex(of: " ") { upper = space }
        let body = String(text[lower..<upper]).trimmingCharacters(in: .whitespaces)
        return (lower > text.startIndex ? "…" : "") + body + (upper < text.endIndex ? "…" : "")
    }

    /// Whether `text` holds `term`, ignoring case and accents.
    static func matches(_ term: String, in text: String) -> Bool {
        text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
