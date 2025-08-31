//
//  Bill+AnchorDueDate.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  Bill+AnchorDueDate.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  © 2025 Rob Adams. All rights reserved.
//

import Foundation

extension Bill {
    /// Treat the stored dueDate as the anchor for recurrence.
    var anchorDueDate: Date { dueDate }

    /// Next due date on/after `date` according to the bill's frequency string.
    /// Returns `nil` for one-time bills that are already in the past.
    func nextOccurrence(onOrAfter date: Date, calendar: Calendar = .current) -> Date? {
        let freq = RepeatFrequency(fuzzy: repeatFrequency) // uses helper in ModelShims.swift

        switch freq {
        case .none:
            return anchorDueDate >= date ? anchorDueDate : nil
        case .weekly:
            return Self.advanceDays(from: anchorDueDate, step: 7, toReachOnOrAfter: date, calendar: calendar)
        case .biweekly:
            return Self.advanceDays(from: anchorDueDate, step: 14, toReachOnOrAfter: date, calendar: calendar)
        case .monthly:
            return Self.advanceMonths(from: anchorDueDate, months: 1, toReachOnOrAfter: date, calendar: calendar)
        case .yearly:
            return Self.advanceYears(from: anchorDueDate, years: 1, toReachOnOrAfter: date, calendar: calendar)
        }
    }

    /// True if the bill has an occurrence within `interval`.
    func occurs(in interval: DateInterval, calendar: Calendar = .current) -> Bool {
        guard let next = nextOccurrence(onOrAfter: interval.start, calendar: calendar) else { return false }
        return interval.contains(next)
    }

    /// Filter a list of bills to those that occur within `interval`.
    static func bills(in interval: DateInterval, from all: [Bill], calendar: Calendar = .current) -> [Bill] {
        all.filter { $0.occurs(in: interval, calendar: calendar) }
    }
}

// MARK: - Recurrence helpers

private extension Bill {
    static func advanceDays(from anchor: Date, step: Int, toReachOnOrAfter target: Date, calendar: Calendar) -> Date {
        guard anchor < target else { return anchor }
        let diff = calendar.dateComponents([.day], from: anchor, to: target).day ?? 0
        let increments = (diff + step - 1) / step // ceiling division
        return calendar.date(byAdding: .day, value: increments * step, to: anchor) ?? target
    }

    static func advanceMonths(from anchor: Date, months: Int, toReachOnOrAfter target: Date, calendar: Calendar) -> Date {
        guard anchor < target else { return anchor }
        let diff = calendar.dateComponents([.month], from: anchor, to: target).month ?? 0
        let candidate = calendar.date(byAdding: .month, value: diff, to: anchor) ?? target
        if candidate >= target { return candidate }
        return calendar.date(byAdding: .month, value: months, to: candidate) ?? target
    }

    static func advanceYears(from anchor: Date, years: Int, toReachOnOrAfter target: Date, calendar: Calendar) -> Date {
        guard anchor < target else { return anchor }
        let diff = calendar.dateComponents([.year], from: anchor, to: target).year ?? 0
        let candidate = calendar.date(byAdding: .year, value: diff, to: anchor) ?? target
        if candidate >= target { return candidate }
        return calendar.date(byAdding: .year, value: years, to: candidate) ?? target
    }
}
