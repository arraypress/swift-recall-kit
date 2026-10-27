//
//  String+NonEmpty.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension String {

    /// The string, or nil when it is empty.
    var nonEmpty: String? { isEmpty ? nil : self }
}
