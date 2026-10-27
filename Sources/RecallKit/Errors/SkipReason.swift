//
//  SkipReason.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Why one source can't be searched for one query — thrown by a searcher,
/// caught by ``Recall`` and reported as a ``RecallSkip``.
struct SkipReason: Error, Equatable {
    /// The reason, in a sentence.
    let text: String

    /// A reason.
    init(_ text: String) { self.text = text }
}
