//
//  DateSpan.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  DueBucket.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//

import Foundation

/// A span of time starting at `start` and optionally ending at `end`.
struct DateSpan: Equatable, Hashable, Codable {
    var start: Date
    var end: Date?   // nil = open-ended

    var isOpenEnded: Bool { end == nil }

    /// Check whether a date falls within the span.
    func contains(_ date: Date) -> Bool {
        if let end {
            return (start ... end) ~= date
        } else {
            return date >= start
        }
    }
}

/// A logical bucket of bills grouped by a due-date window.
struct DueBucket: Equatable, Hashable, Codable, Identifiable {
    var id = UUID()
    var title: String
    var span: DateSpan
}
