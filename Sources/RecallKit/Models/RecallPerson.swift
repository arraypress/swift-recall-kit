//
//  RecallPerson.swift
//  RecallKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Who a person query turned out to be: the names it matched and every
/// address those people are known by.
public struct RecallPerson: Sendable, Equatable, Codable {
    /// What was asked for.
    public var query: String
    /// The names of the contacts it matched; empty when it was an address
    /// or matched no contact.
    public var names: [String]
    /// Their phone numbers, as stored.
    public var phones: [String]
    /// Their email addresses.
    public var emails: [String]

    /// A resolved person.
    ///
    /// - Parameters:
    ///   - query: What was asked for.
    ///   - names: The contacts' names.
    ///   - phones: Their phone numbers.
    ///   - emails: Their email addresses.
    public init(query: String, names: [String] = [], phones: [String] = [], emails: [String] = []) {
        self.query = query
        self.names = names
        self.phones = phones
        self.emails = emails
    }
}
