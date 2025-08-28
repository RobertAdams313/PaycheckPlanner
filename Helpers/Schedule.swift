//
//  PayFrequency.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation

enum PayFrequency: String {
    case weekly, biweekly, monthly
}

struct Schedule {
    static func nextPayDates(from startDate: Date, frequency: String, count: Int = 6) -> [Date] {
        var dates: [Date] = []
        var current = startDate
        let cal = Calendar.current
        let freq = PayFrequency(rawValue: frequency.lowercased())

        for _ in 0..<count {
            dates.append(current)
            switch freq {
            case .weekly:
                current = cal.date(byAdding: .weekOfYear, value: 1, to: current) ?? current
            case .biweekly:
                current = cal.date(byAdding: .weekOfYear, value: 2, to: current) ?? current
            case .monthly:
                current = cal.date(byAdding: .month, value: 1, to: current) ?? current
            case .none:
                return dates
            }
        }
        return dates
    }

    static func periodEnd(for start: Date, frequency: String) -> Date {
        let cal = Calendar.current
        switch frequency.lowercased() {
        case "weekly":   return cal.date(byAdding: .day, value: 7, to: start) ?? start
        case "biweekly": return cal.date(byAdding: .day, value: 14, to: start) ?? start
        case "monthly":  return cal.date(byAdding: .month, value: 1, to: start) ?? start
        default:         return start
        }
    }
}
