//
//  init.swift
//  Paycheck Planner
//
//  Created by Rob on 8/28/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  ModelShims.swift
//  Paycheck Planner
//
//  Centralized helpers that keep the Bill model storage simple
//  (repeatFrequency as String, amount as Double) while giving
//  the UI and business logic a type-safe API.
//
//  Place this file ONCE in the project to avoid redeclaration conflicts.
//

import Foundation

// MARK: - RepeatFrequency (type-safe view/logic layer)

/// Canonical frequency tokens we store on Bill.repeatFrequency are:
/// "one-time", "weekly", "biweekly", "monthly", "yearly"
enum RepeatFrequency: String, CaseIterable, Identifiable, Codable {
    case none      = "one-time"
    case weekly    = "weekly"
    case biweekly  = "biweekly"
    case monthly   = "monthly"
    case yearly    = "yearly"

    var id: String { rawValue }

    /// Human-readable label for UI.
    var displayName: String {
        switch self {
        case .none:     return "One Time"
        case .weekly:   return "Weekly"
        case .biweekly: return "Biweekly"
        case .monthly:  return "Monthly"
        case .yearly:   return "Yearly"
        }
    }

    /// Fuzzy parser that accepts historic/variant strings.
    /// Examples accepted: "Biweekly", "every 2 weeks", "one time", "annually", etc.
    init(fuzzy raw: String) {
        let s = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        switch s {
        case "weekly":
            self = .weekly
        case "biweekly", "every-2-weeks", "every 2 weeks", "every two weeks", "fortnightly":
            self = .biweekly
        case "monthly":
            self = .monthly
        case "yearly", "annual", "annually":
            self = .yearly
        case "one-time", "one time", "once", "none", "":
            fallthrough
        default:
            self = .none
        }
    }

    /// The date-component "step" for generating periods.
    var stepComponents: DateComponents {
        switch self {
        case .none:     return DateComponents(day: 0)   // no recurrence
        case .weekly:   return DateComponents(day: 7)
        case .biweekly: return DateComponents(day: 14)
        case .monthly:  return DateComponents(month: 1)
        case .yearly:   return DateComponents(year: 1)
        }
    }

    /// Produce the next contiguous period starting at `start`.
    /// For one-time, returns a zero-length interval anchored at `start`.
    func period(from start: Date, using calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .none:
            return DateInterval(start: start, end: start)
        default:
            let end = calendar.date(byAdding: stepComponents, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }
}

// MARK: - Bill conveniences (bridging to the enum and currency helpers)

extension Bill {
    /// Type-safe frequency exposure for views/business logic.
    var repeatFrequencyEnum: RepeatFrequency {
        get { RepeatFrequency(fuzzy: repeatFrequency) }
        set { repeatFrequency = newValue.rawValue }
    }

    /// Optional helpers if a view prefers Decimal for money math.
    var amountDecimal: Decimal {
        get { Decimal(amount) }
        set { amount = NSDecimalNumber(decimal: newValue).doubleValue }
    }

    /// Convenience formatters (use sparingly to avoid re-creating formatters).
    var amountCurrencyString: String {
        let code = Locale.current.currency?.identifier ?? "USD"
        return amount.formatted(.currency(code: code))
    }
}

// MARK: - Period utilities

struct Periods {
    /// Build `count` contiguous periods from an `anchor` using a frequency.
    static func next(from anchor: Date,
                     frequency: RepeatFrequency,
                     count: Int,
                     calendar: Calendar = .current) -> [DateInterval] {
        guard count > 0 else { return [] }
        var result: [DateInterval] = []
        var currentStart = anchor
        for _ in 0..<count {
            let interval = frequency.period(from: currentStart, using: calendar)
            result.append(interval)
            currentStart = interval.end
        }
        return result
    }
}
