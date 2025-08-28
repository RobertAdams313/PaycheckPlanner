//
//  DateUtils.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation

enum DateUtils {
    static let cal = Calendar.current

    static func startOfDay(_ date: Date) -> Date {
        cal.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date) -> Date {
        let start = startOfDay(date)
        return cal.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? date
    }

    static func inRange(_ date: Date, _ start: Date, _ end: Date) -> Bool {
        (date >= start) && (date < end)
    }
}
