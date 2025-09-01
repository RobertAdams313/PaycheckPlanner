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

    /// Build upcoming combined pay periods.
    ///
    /// If there is exactly **one recurring** income schedule (weekly/biweekly/monthly/semimonthly),
    /// we use that schedule to define the period grid:
    ///     [previous payday ≤ now] → [next payday ≥ now] → [next] → ...
    ///
    /// That guarantees the first period shown is the **current open period** (e.g., Aug 22–Sep 5).
    /// We still include incomes from *all* schedules that pay exactly on each period `end` (payday).
    ///
    /// If there are multiple recurring schedules, we fall back to the merged-paydays method.
    static func combinedPeriods(
        schedules: [IncomeSchedule],
        count: Int,
        from startFrom: Date = .now,
        using cal: Calendar = .init(identifier: .gregorian)
    ) -> [CombinedPeriod] {
        guard count > 0 else { return [] }

        let lower = stripTime(startFrom, cal: cal)
        let recurring = schedules.filter { $0.frequency != .once }

        // Preferred path: single recurring schedule defines the grid.
        if recurring.count == 1, let anchorSch = recurring.first {
            return periodsUsingAnchor(anchorSch, allSchedules: schedules, count: count, lower: lower, cal: cal)
        }

        // Fallback: merged-paydays method (kept, but seeded with "previous payday" to ensure an open period).
        return periodsUsingMergedGrid(schedules: schedules, count: count, lower: lower, cal: cal)
    }

    // MARK: - Primary grid (single recurring schedule)

    private static func periodsUsingAnchor(
        _ anchor: IncomeSchedule,
        allSchedules: [IncomeSchedule],
        count: Int,
        lower: Date,
        cal: Calendar
    ) -> [CombinedPeriod] {
        // previous payday at/before now
        guard let prev = previousPayday(for: anchor, atOrBefore: lower, cal: cal) else {
            return [] // shouldn’t happen for recurring; safeguard
        }

        // next N paydays ≥ now
        var nexts = nextPaydays(for: anchor, count: count, from: lower, using: cal)

        // Ensure we have enough bounds (prev + nexts >= count+1)
        while nexts.count < count, let last = nexts.last ?? Optional.some(prev) {
            // extend further
            let more = nextPaydays(for: anchor, count: 4, from: last, using: cal)
            if more.isEmpty { break }
            nexts.append(contentsOf: more)
        }

        // Build periods between consecutive bounds: prev -> nexts[0], nexts[0] -> nexts[1], ...
        var periods: [CombinedPeriod] = []
        var bounds: [Date] = [prev] + nexts
        let limit = min(count, max(0, bounds.count - 1))

        for i in 0..<limit {
            let start = bounds[i]
            let end = bounds[i + 1]

            // incomes that pay exactly on the end date (payday)
            let incomes: [PeriodIncome] = allSchedules.compactMap { sch in
                guard paysOn(end, schedule: sch, cal: cal),
                      let src = sch.source ?? sch.ownerSource else { return nil }
                return PeriodIncome(source: src, amount: src.defaultAmount)
            }

            periods.append(.init(start: start, end: end, payday: end, incomes: incomes))
        }

        return periods
    }

    // MARK: - Fallback merged grid (multiple recurring schedules)

    private static func periodsUsingMergedGrid(
        schedules: [IncomeSchedule],
        count: Int,
        lower: Date,
        cal: Calendar
    ) -> [CombinedPeriod] {

        var merged: Set<Date> = []
        var schedulePaydays: [ObjectIdentifier: [Date]] = [:]

        for sch in schedules {
            let key = ObjectIdentifier(sch)
            let prev = previousPayday(for: sch, atOrBefore: lower, cal: cal)
            let nexts = nextPaydays(for: sch, count: count + 2, from: lower, using: cal)

            if let p = prev { merged.insert(p) }
            for d in nexts { merged.insert(d) }

            schedulePaydays[key] = (prev.map { [$0] } ?? []) + nexts
        }

        var all = Array(merged).sorted()
        guard !all.isEmpty else { return [] }

        // If the smallest merged date is AFTER lower, seed a previous bound from any schedule
        if let first = all.first, first > lower {
            if let near = schedules.compactMap({ previousPayday(for: $0, atOrBefore: lower, cal: cal) }).max() {
                all.insert(near, at: 0)
            }
        }

        var periods: [CombinedPeriod] = []
        for i in 1..<all.count {
            let prev = all[i - 1]
            let next = all[i]

            let incomes: [PeriodIncome] = schedules.compactMap { sch in
                let key = ObjectIdentifier(sch)
                if let list = schedulePaydays[key], list.contains(next),
                   let src = sch.source ?? sch.ownerSource {
                    return PeriodIncome(source: src, amount: src.defaultAmount)
                }
                return nil
            }

            periods.append(.init(start: prev, end: next, payday: next, incomes: incomes))
            if periods.count >= count { break }
        }

        // Extend if needed
        if periods.count < count, let lastEnd = periods.last?.end {
            var tail = Set(all)
            for sch in schedules {
                for d in nextPaydays(for: sch, count: count + 4, from: lastEnd, using: cal) {
                    tail.insert(d)
                }
            }
            let sortedTail = Array(tail).sorted()
            var i = 1
            while periods.count < count && i < sortedTail.count {
                let prev = sortedTail[i - 1]
                let next = sortedTail[i]

                let incomes: [PeriodIncome] = schedules.compactMap { sch in
                    let key = ObjectIdentifier(sch)
                    if let list = schedulePaydays[key], list.contains(next),
                       let src = sch.source ?? sch.ownerSource {
                        return PeriodIncome(source: src, amount: src.defaultAmount)
                    }
                    return nil
                }

                if periods.last?.start != prev || periods.last?.end != next {
                    periods.append(.init(start: prev, end: next, payday: next, incomes: incomes))
                }
                i += 1
            }
        }

        return periods
    }

    // MARK: - Payday generation per schedule

    private static func previousPayday(
        for sch: IncomeSchedule,
        atOrBefore lower: Date,
        cal: Calendar
    ) -> Date? {
        switch sch.frequency {
        case .once:
            let d = stripTime(sch.anchorDate, cal: cal)
            return d <= lower ? d : nil
        case .weekly:
            return strideBackwardsDays(anchor: sch.anchorDate, every: 7, atOrBefore: lower, cal: cal)
        case .biweekly:
            return strideBackwardsDays(anchor: sch.anchorDate, every: 14, atOrBefore: lower, cal: cal)
        case .monthly:
            return monthlyBackwards(anchor: sch.anchorDate, atOrBefore: lower, cal: cal)
        case .semimonthly:
            return semiMonthlyBackwards(anchor: sch.anchorDate, d1: sch.semimonthlyFirstDay, d2: sch.semimonthlySecondDay, atOrBefore: lower, cal: cal)
        }
    }

    private static func nextPaydays(
        for sch: IncomeSchedule,
        count: Int,
        from lower: Date,
        using cal: Calendar
    ) -> [Date] {
        switch sch.frequency {
        case .once:
            return sch.anchorDate >= lower ? [stripTime(sch.anchorDate, cal: cal)] : []
        case .weekly:
            return strideDays(anchor: sch.anchorDate, every: 7, atOrAfter: lower, count: count, cal: cal)
        case .biweekly:
            return strideDays(anchor: sch.anchorDate, every: 14, atOrAfter: lower, count: count, cal: cal)
        case .monthly:
            let day = cal.component(.day, from: sch.anchorDate)
            return strideMonthly(anchor: sch.anchorDate, day: day, atOrAfter: lower, count: count, cal: cal)
        case .semimonthly:
            return strideSemiMonthly(anchor: sch.anchorDate, d1: sch.semimonthlyFirstDay, d2: sch.semimonthlySecondDay, atOrAfter: lower, count: count, cal: cal)
        }
    }

    // MARK: - “Does this schedule pay on this date?”

    private static func paysOn(_ date: Date, schedule sch: IncomeSchedule, cal: Calendar) -> Bool {
        let d = stripTime(date, cal: cal)
        let a = stripTime(sch.anchorDate, cal: cal)

        switch sch.frequency {
        case .once:
            return d == a
        case .weekly:
            if let delta = cal.dateComponents([(.day)], from: a, to: d).day { return delta >= 0 && delta % 7 == 0 }
            return false
        case .biweekly:
            if let delta = cal.dateComponents([(.day)], from: a, to: d).day { return delta >= 0 && delta % 14 == 0 }
            return false
        case .monthly:
            let anchorDay = max(1, min(28, cal.component(.day, from: a)))
            return cal.component(.day, from: d) == anchorDay
        case .semimonthly:
            let ad1 = max(1, min(28, sch.semimonthlyFirstDay))
            let ad2 = max(1, min(28, sch.semimonthlySecondDay))
            let dd = cal.component(.day, from: d)
            return dd == ad1 || dd == ad2
        }
    }

    // MARK: - Stride helpers (forward)

    private static func strideDays(
        anchor: Date,
        every days: Int,
        atOrAfter lower: Date,
        count: Int,
        cal: Calendar
    ) -> [Date] {
        var occurrences: [Date] = []
        var d = stripTime(anchor, cal: cal)
        while d < lower {
            guard let nd = cal.date(byAdding: .day, value: days, to: d) else { break }
            d = nd
        }
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
            var comps = cursor; comps.day = dayClamped
            if let candidate = cal.date(from: comps) {
                let c = stripTime(candidate, cal: cal)
                if c >= stripTime(lower, cal: cal) { out.append(c) }
            }
            // next month
            if let nextMonth = cal.date(from: DateComponents(year: cursor.year, month: (cursor.month ?? 1) + 1)),
               let nextComps = cal.dateComponents([.year, .month], from: nextMonth) as DateComponents? {
                cursor = nextComps
            } else { break }
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
                var comps = cursor; comps.day = dd
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
            } else { break }
        }
        return out
    }

    // MARK: - Stride helpers (backwards)

    private static func strideBackwardsDays(anchor: Date, every days: Int, atOrBefore lower: Date, cal: Calendar) -> Date? {
        var d = stripTime(anchor, cal: cal)
        if d > lower {
            while d > lower {
                guard let nd = cal.date(byAdding: .day, value: -days, to: d) else { break }
                d = nd
            }
            return d <= lower ? d : nil
        } else {
            var prev = d
            while d <= lower {
                prev = d
                guard let nd = cal.date(byAdding: .day, value: days, to: d) else { break }
                d = nd
            }
            return prev
        }
    }

    private static func monthlyBackwards(anchor: Date, atOrBefore lower: Date, cal: Calendar) -> Date? {
        let day = max(1, min(28, cal.component(.day, from: anchor)))
        var comps = cal.dateComponents([.year, .month], from: lower)
        var candidate: Date? = nil
        if let y = comps.year, let m = comps.month {
            var c = DateComponents(); c.year = y; c.month = m; c.day = day
            candidate = cal.date(from: c)
            if let cand = candidate, stripTime(cand, cal: cal) > stripTime(lower, cal: cal) {
                if let pm = cal.date(from: DateComponents(year: y, month: m - 1)),
                   let pc = cal.dateComponents([.year, .month], from: pm) as DateComponents? {
                    var pc2 = pc; pc2.day = day
                    candidate = cal.date(from: pc2)
                }
            }
        }
        return candidate.map { stripTime($0, cal: cal) }
    }

    private static func semiMonthlyBackwards(anchor: Date, d1: Int, d2: Int, atOrBefore lower: Date, cal: Calendar) -> Date? {
        let days = [max(1, min(28, d1)), max(1, min(28, d2))].sorted()
        var comps = cal.dateComponents([.year, .month], from: lower)

        func candidate(in comps: DateComponents) -> Date? {
            var cands: [Date] = []
            for dd in days {
                var c = comps; c.day = dd
                if let d = cal.date(from: c) {
                    let s = stripTime(d, cal: cal)
                    if s <= stripTime(lower, cal: cal) { cands.append(s) }
                }
            }
            return cands.max()
        }

        if let cand = candidate(in: comps) { return cand }
        if let pm = cal.date(from: DateComponents(year: comps.year, month: (comps.month ?? 1) - 1)),
           let pc = cal.dateComponents([.year, .month], from: pm) as DateComponents? {
            return candidate(in: pc)
        }
        return nil
    }

    // MARK: - Helpers

    private static func stripTime(_ d: Date, cal: Calendar) -> Date {
        cal.startOfDay(for: d)
    }

    private static func stripToYearMonth(_ d: Date, cal: Calendar) -> DateComponents {
        cal.dateComponents([.year, .month], from: d)
    }
}

// MARK: - Convenience to reach IncomeSource/amount from schedule safely

private extension IncomeSchedule {
    var ownerSource: IncomeSource? { self.source }
    var ownerSourceDefaultAmount: Decimal { (ownerSource?.defaultAmount) ?? 0 }
}
