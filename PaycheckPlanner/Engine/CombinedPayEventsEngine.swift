//
//  CombinedPeriod.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation
import SwiftData

// MARK: - Types (internal)

struct CombinedPeriod: Identifiable, Hashable {
    let id = UUID()
    let start: Date
    let end: Date
    let payday: Date
    let incomes: [PeriodIncome]
    var incomeTotal: Decimal { incomes.reduce(0) { $0 + $1.amount } }
}

struct PeriodIncome: Identifiable, Hashable {
    let id = UUID()
    let source: IncomeSource
    let amount: Decimal
}

private struct PayEvent: Identifiable, Hashable {
    let id = UUID()
    let payday: Date
    let source: IncomeSource
    let amount: Decimal
}

// MARK: - Engine

enum CombinedPayEventsEngine {
    static func combinedPeriods(
        schedules: [IncomeSchedule],
        count: Int = 6,
        now: Date = .now
    ) -> [CombinedPeriod] {
        let cal = Calendar(identifier: .gregorian)

        var events: [PayEvent] = []
        for s in schedules {
            guard let source = s.source else { continue }
            let pays = nextPaydays(for: s, count: count * 2, from: now, using: cal)
            for d in pays { events.append(.init(payday: d, source: source, amount: source.defaultAmount)) }
        }

        events.sort { $0.payday < $1.payday }
        guard !events.isEmpty else { return [] }

        var result: [CombinedPeriod] = []
        var boundary = now
        var idx = 0

        while idx < events.count && result.count < count {
            let day = cal.startOfDay(for: events[idx].payday)
            var sameDay: [PayEvent] = []
            while idx < events.count && cal.isDate(events[idx].payday, inSameDayAs: day) {
                sameDay.append(events[idx]); idx += 1
            }
            let incomes = sameDay.map { PeriodIncome(source: $0.source, amount: $0.amount) }
            let payday = sameDay.first!.payday
            result.append(.init(start: boundary, end: payday, payday: payday, incomes: incomes))
            boundary = payday
        }
        return result
    }

    // MARK: helpers

    private static func nextPaydays(for sch: IncomeSchedule, count: Int, from: Date, using cal: Calendar) -> [Date] {
        switch sch.frequency {
        case .weekly:
            return strideDays(from: sch.anchorDate, every: 7, atOrAfter: from, count: count, cal: cal)
        case .biweekly:
            return strideDays(from: sch.anchorDate, every: 14, atOrAfter: from, count: count, cal: cal)
        case .monthly:
            return strideMonthly(anchor: sch.anchorDate,
                                 day: cal.component(.day, from: sch.anchorDate),
                                 atOrAfter: from, count: count, cal: cal)
        case .semimonthly:
            let d1 = max(1, min(28, sch.semimonthlyFirstDay))
            let d2 = max(1, min(28, sch.semimonthlySecondDay))
            return strideSemiMonthly(d1: d1, d2: d2, atOrAfter: from, count: count, cal: cal)
        }
    }

    private static func strideDays(from anchor: Date, every days: Int,
                                   atOrAfter lower: Date, count: Int, cal: Calendar) -> [Date] {
        var d = anchor
        while d < lower {
            d = cal.date(byAdding: .day, value: days, to: d) ?? d.addingTimeInterval(Double(days) * 86400)
        }
        var out: [Date] = []
        for _ in 0..<count {
            out.append(d)
            d = cal.date(byAdding: .day, value: days, to: d) ?? d.addingTimeInterval(Double(days) * 86400)
        }
        return out
    }

    private static func strideMonthly(anchor: Date, day: Int,
                                      atOrAfter lower: Date, count: Int, cal: Calendar) -> [Date] {
        var comps = cal.dateComponents([.year, .month], from: anchor)
        comps.day = max(1, min(28, day))
        var d = cal.date(from: comps) ?? anchor
        while d < lower { comps.month = (comps.month ?? 1) + 1; d = cal.date(from: comps) ?? d }

        var out: [Date] = []
        for _ in 0..<count {
            out.append(d)
            comps.month = (comps.month ?? 1) + 1
            d = cal.date(from: comps) ?? d
        }
        return out
    }

    private static func strideSemiMonthly(d1: Int, d2: Int,
                                          atOrAfter lower: Date, count: Int, cal: Calendar) -> [Date] {
        var out: [Date] = []
        var comps = cal.dateComponents([.year, .month], from: lower)
        while out.count < count {
            guard let y = comps.year, let m = comps.month else { break }
            for dd in [min(d1, d2), max(d1, d2)] {
                var c = DateComponents(); c.year = y; c.month = m; c.day = max(1, min(28, dd))
                if let d = cal.date(from: c), d >= lower { out.append(d); if out.count == count { break } }
            }
            comps.month = m + 1
        }
        return out
    }
}
