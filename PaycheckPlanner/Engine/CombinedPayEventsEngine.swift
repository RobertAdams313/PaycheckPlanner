//
//  CombinedPeriod.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  CombinedPayEventsEngine.swift
//  PaycheckPlanner
//

import Foundation
import SwiftData

// MARK: - Period models used by views/engines

struct PeriodIncome: Identifiable, Hashable {
    let id = UUID()
    let source: IncomeSource
    let amount: Decimal
}

struct CombinedPeriod: Identifiable, Hashable {
    let id = UUID()
    let start: Date
    let end: Date
    let payday: Date
    let incomes: [PeriodIncome]

    var incomeTotal: Decimal { incomes.reduce(0) { $0 + $1.amount } }
}

// MARK: - Engine

enum CombinedPayEventsEngine {

    /// Build upcoming combined pay periods from all income schedules.
    /// Each period spans (previous payday, next payday) with strict end bound.
    static func combinedPeriods(
        schedules: [IncomeSchedule],
        count: Int,
        from startFrom: Date = .now,
        using cal: Calendar = .init(identifier: .gregorian)
    ) -> [CombinedPeriod] {
        guard count > 0 else { return [] }

        // Gather upcoming paydays for each schedule
        let perSchedulePaydays: [[Date]] = schedules.map { sch in
            nextPaydays(for: sch, count: count + 2, from: startFrom, using: cal) // small buffer
        }

        // Merge unique and sort
        let allPaydays = Array(Set(perSchedulePaydays.flatMap { $0 })).sorted()

        // Early out if no paydays
        guard !allPaydays.isEmpty else { return [] }

        // Build consecutive periods
        var periods: [CombinedPeriod] = []
        for i in 1..<allPaydays.count {
            let prev = allPaydays[i-1]
            let next = allPaydays[i]
            // Period spans (prev, next) — exclusive of next
            let incomeForThisPayday: [PeriodIncome] = schedules.compactMap { sch in
                // If this schedule has a payday exactly on `next`, include its income
                // (we compare by day granularity to avoid time components issues)
                if isSameDay(schPayday: next, in: sch, cal: cal) {
                    let amount = sch.source?.defaultAmount ?? sch.ownerSourceDefaultAmount
                    if let src = sch.source ?? sch.ownerSource {
                        return PeriodIncome(source: src, amount: amount)
                    }
                }
                return nil
            }
            periods.append(CombinedPeriod(start: prev, end: next, payday: next, incomes: incomeForThisPayday))
            if periods.count >= count { break }
        }

        // If we didn't reach `count` (e.g., very sparse schedules), try to extend
        if periods.count < count, let last = allPaydays.last {
            // Synthesize additional consecutive periods from the farthest schedules
            // by asking each schedule for a few more occurrences past `last`
            var tail = allPaydays
            let extras = schedules.flatMap { sch in
                nextPaydays(for: sch, count: count + 2, from: last, using: cal)
            }
            tail.append(contentsOf: extras)
            let uniqueTail = Array(Set(tail)).sorted()

            var i = 1
            while periods.count < count, i < uniqueTail.count {
                let prev = uniqueTail[i-1]
                let next = uniqueTail[i]
                let incomeForThisPayday: [PeriodIncome] = schedules.compactMap { sch in
                    if isSameDay(schPayday: next, in: sch, cal: cal) {
                        let amount = sch.source?.defaultAmount ?? sch.ownerSourceDefaultAmount
                        if let src = sch.source ?? sch.ownerSource {
                            return PeriodIncome(source: src, amount: amount)
                        }
                    }
                    return nil
                }
                // Avoid duplicate periods with identical bounds
                if periods.last?.start != prev || periods.last?.end != next {
                    periods.append(CombinedPeriod(start: prev, end: next, payday: next, incomes: incomeForThisPayday))
                }
                i += 1
            }
        }

        return periods
    }

    // MARK: - Payday generation per schedule

    private static func nextPaydays(
        for sch: IncomeSchedule,
        count: Int,
        from lower: Date,
        using cal: Calendar
    ) -> [Date] {
        switch sch.frequency {
        case .once:
            // Single payday at anchorDate if it's at/after lower bound
            return sch.anchorDate >= lower ? [stripTime(sch.anchorDate, cal: cal)] : []

        case .weekly:
            return strideDays(anchor: sch.anchorDate, every: 7, atOrAfter: lower, count: count, cal: cal)

        case .biweekly:
            return strideDays(anchor: sch.anchorDate, every: 14, atOrAfter: lower, count: count, cal: cal)

        case .monthly:
            let day = cal.component(.day, from: sch.anchorDate)
            return strideMonthly(anchor: sch.anchorDate, day: day, atOrAfter: lower, count: count, cal: cal)

        case .semimonthly:
            return strideSemiMonthly(
                anchor: sch.anchorDate,
                d1: sch.semimonthlyFirstDay,
                d2: sch.semimonthlySecondDay,
                atOrAfter: lower,
                count: count,
                cal: cal
            )
        }
    }

    // MARK: - Stride helpers (with labels that match call sites)

    private static func strideDays(
        anchor: Date,
        every days: Int,
        atOrAfter lower: Date,
        count: Int,
        cal: Calendar
    ) -> [Date] {
        var occurrences: [Date] = []
        var d = anchor
        // Move to first occurrence >= lower
        while d < lower {
            guard let nd = cal.date(byAdding: .day, value: days, to: d) else { break }
            d = nd
        }
        // Emit up to count occurrences
        while occurrences.count < count {
            occurrences.append(stripTime(d, cal: cal))
            guard let nd = cal.date(byAdding: .day, value: days, to: d) else { break }
            d = nd
        }
        return occurrences
    }

    private static func strideMonthly(
        anchor: Date,
        day: Int,
        atOrAfter lower: Date,
        count: Int,
        cal: Calendar
    ) -> [Date] {
        let dayClamped = max(1, min(28, day))
        var cursor = stripToYearMonth(lower, cal: cal)
        var out: [Date] = []
        while out.count < count {
            var comps = cursor
            comps.day = dayClamped
            if let candidate = cal.date(from: comps) {
                let c = stripTime(candidate, cal: cal)
                if c >= stripTime(lower, cal: cal) {
                    out.append(c)
                }
            }
            // next month
            if let nextMonth = cal.date(from: DateComponents(year: cursor.year, month: (cursor.month ?? 1) + 1)),
               let nextComps = cal.dateComponents([.year, .month], from: nextMonth) as DateComponents? {
                cursor = nextComps
            } else {
                break
            }
        }
        return out
    }

    private static func strideSemiMonthly(
        anchor: Date,
        d1: Int,
        d2: Int,
        atOrAfter lower: Date,
        count: Int,
        cal: Calendar
    ) -> [Date] {
        let days = [max(1, min(28, d1)), max(1, min(28, d2))].sorted()
        var cursor = stripToYearMonth(lower, cal: cal)
        var out: [Date] = []
        while out.count < count {
            for dd in days {
                var comps = cursor
                comps.day = dd
                if let candidate = cal.date(from: comps) {
                    let c = stripTime(candidate, cal: cal)
                    if c >= stripTime(lower, cal: cal) {
                        out.append(c)
                        if out.count >= count { break }
                    }
                }
            }
            // next month
            if let nextMonth = cal.date(from: DateComponents(year: cursor.year, month: (cursor.month ?? 1) + 1)),
               let nextComps = cal.dateComponents([.year, .month], from: nextMonth) as DateComponents? {
                cursor = nextComps
            } else {
                break
            }
        }
        return out
    }

    // MARK: - Helpers

    private static func isSameDay(schPayday: Date, in sch: IncomeSchedule, cal: Calendar) -> Bool {
        // a schedule "pays" on schPayday if schPayday is one of its generated next paydays
        // We check by day equality
        let a = stripTime(schPayday, cal: cal)
        let b = stripTime(sch.anchorDate, cal: cal)
        switch sch.frequency {
        case .once:
            return a == stripTime(sch.anchorDate, cal: cal)
        case .weekly:
            return strideDays(anchor: b, every: 7, atOrAfter: a, count: 1, cal: cal).first == a
                || strideDays(anchor: b, every: 7, atOrAfter: b, count: 500, cal: cal).contains(a)
        case .biweekly:
            return strideDays(anchor: b, every: 14, atOrAfter: b, count: 500, cal: cal).contains(a)
        case .monthly:
            let day = cal.component(.day, from: sch.anchorDate)
            return strideMonthly(anchor: b, day: day, atOrAfter: b, count: 200, cal: cal).contains(a)
        case .semimonthly:
            return strideSemiMonthly(anchor: b, d1: sch.semimonthlyFirstDay, d2: sch.semimonthlySecondDay, atOrAfter: b, count: 300, cal: cal).contains(a)
        }
    }

    private static func stripTime(_ d: Date, cal: Calendar) -> Date {
        cal.startOfDay(for: d)
    }

    private static func stripToYearMonth(_ d: Date, cal: Calendar) -> DateComponents {
        cal.dateComponents([.year, .month], from: d)
    }
}

// MARK: - Convenience to reach IncomeSource/amount from schedule safely

private extension IncomeSchedule {
    /// Try to reference an owning IncomeSource if not directly held (depends on your model wiring).
    var ownerSource: IncomeSource? {
        // If your model has a back-reference, use that.
        // Otherwise rely on schedule.source if present (adjust to your schema).
        return self.source
    }
    var ownerSourceDefaultAmount: Decimal {
        (ownerSource?.defaultAmount) ?? 0
    }
}
