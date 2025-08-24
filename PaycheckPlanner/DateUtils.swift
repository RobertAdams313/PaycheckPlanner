//
//  PayDateUtils.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation

/// Safe payday utilities that avoid force-unwraps and handle empty arrays gracefully.
struct PayDateUtils {
    static func previousPayday(schedule: PaySchedule, paydays: [Date]) -> Date {
        let cal = Calendar.current
        let base = paydays.first ?? schedule.anchorDate

        switch schedule.frequency {
        case .weekly:
            return cal.date(byAdding: .day, value: -7, to: base) ?? base
        case .biweekly:
            return cal.date(byAdding: .day, value: -14, to: base) ?? base
        case .semimonthly:
            return previousSemimonthly(base: base, schedule: schedule, calendar: cal)
        case .monthly:
            return cal.date(byAdding: .month, value: -1, to: base) ?? base
        }
    }

    static func futurePaydays(schedule: PaySchedule, count: Int) -> [Date] {
        var results: [Date] = []
        let cal = Calendar.current
        var current = cal.startOfDay(for: schedule.anchorDate)
        let n = max(1, count)

        switch schedule.frequency {
        case .weekly:
            for i in 0..<n { if i > 0 { current = cal.date(byAdding: .day, value: 7, to: current) ?? current }; results.append(current) }
        case .biweekly:
            for i in 0..<n { if i > 0 { current = cal.date(byAdding: .day, value: 14, to: current) ?? current }; results.append(current) }
        case .semimonthly:
            var date = nextSemimonthly(onOrAfter: current, schedule: schedule, calendar: cal)
            results.append(date)
            while results.count < n {
                date = nextSemimonthly(after: date, schedule: schedule, calendar: cal)
                results.append(date)
            }
        case .monthly:
            for i in 0..<n { if i > 0 { current = cal.date(byAdding: .month, value: 1, to: current) ?? current }; results.append(current) }
        }
        return results
    }

    // MARK: - Semimonthly helpers

    static func nextSemimonthly(onOrAfter base: Date, schedule: PaySchedule, calendar cal: Calendar) -> Date {
        let d1 = max(1, min(schedule.semimonthlyFirstDay, 28))
        let d2 = max(1, min(schedule.semimonthlySecondDay, 28))
        let low = min(d1, d2), high = max(d1, d2)

        var comps = cal.dateComponents([.year, .month, .day], from: base)
        let day = comps.day ?? low

        if day <= low {
            comps.day = low
            return cal.date(from: comps) ?? base
        } else if day <= high {
            comps.day = high
            return cal.date(from: comps) ?? base
        } else {
            let next = cal.date(byAdding: .month, value: 1, to: base) ?? base
            var c = cal.dateComponents([.year, .month], from: next)
            c.day = low
            return cal.date(from: c) ?? base
        }
    }

    static func nextSemimonthly(after date: Date, schedule: PaySchedule, calendar cal: Calendar) -> Date {
        let d1 = max(1, min(schedule.semimonthlyFirstDay, 28))
        let d2 = max(1, min(schedule.semimonthlySecondDay, 28))
        let low = min(d1, d2), high = max(d1, d2)

        let comps = cal.dateComponents([.year, .month, .day], from: date)
        if (comps.day ?? low) == low {
            var c = comps; c.day = high
            return cal.date(from: c) ?? date
        } else {
            let next = cal.date(byAdding: .month, value: 1, to: date) ?? date
            var c = cal.dateComponents([.year, .month], from: next)
            c.day = low
            return cal.date(from: c) ?? date
        }
    }

    static func previousSemimonthly(base: Date, schedule: PaySchedule, calendar cal: Calendar) -> Date {
        let d1 = max(1, min(schedule.semimonthlyFirstDay, 28))
        let d2 = max(1, min(schedule.semimonthlySecondDay, 28))
        let low = min(d1, d2), high = max(d1, d2)

        var comps = cal.dateComponents([.year, .month, .day], from: base)
        let currentDay = comps.day ?? low

        func mkDate(year: Int, month: Int, day: Int) -> Date? {
            var c = DateComponents(); c.year = year; c.month = month; c.day = day
            return cal.date(from: c)
        }

        let y = comps.year ?? 2000
        let m = comps.month ?? 1

        if currentDay <= low {
            let prevMonth = cal.date(byAdding: .month, value: -1, to: base) ?? base
            let ym = cal.dateComponents([.year, .month], from: prevMonth)
            return mkDate(year: ym.year ?? y, month: ym.month ?? m, day: high) ?? base
        } else if currentDay <= high {
            comps.day = low
            return cal.date(from: comps) ?? base
        } else {
            comps.day = high
            return cal.date(from: comps) ?? base
        }
    }
}
