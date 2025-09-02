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
//  Rewritten to drive period generation from IncomeSchedule,
//  fixing biweekly slicing and ensuring incomes are counted
//  on each period end (payday).
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
    /// This guarantees the first period shown is the **current open period**.
    /// We still include incomes from *all* schedules that pay exactly on each period `end` (payday).
    ///
    /// If there are multiple recurring schedules, we fall back to a merged-paydays method.
    static func combinedPeriods(
        schedules: [IncomeSchedule],
        count: Int,
        from startFrom: Date = Date.now,
        using cal: Calendar = Calendar(identifier: .gregorian)
    ) -> [CombinedPeriod] {
        guard count > 0 else { return [] }

        let lower = stripTime(startFrom, cal: cal)
        let recurring = schedules.filter { $0.frequency != .once }

        // Preferred path: single recurring schedule defines the grid.
        if recurring.count == 1, let anchorSch = recurring.first {
            return periodsUsingAnchor(anchorSch, allSchedules: schedules, count: count, lower: lower, cal: cal)
        }

        // Fallback: merged-paydays method (works for multiple overlapping schedules).
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
        guard let prev = previousPayday(for: anchor, atOrBefore: lower, cal: cal) else { return [] }

        var nexts = nextPaydays(for: anchor, count: count, from: lower, using: cal)
        // Ensure we have enough bounds (prev + nexts >= count+1)
        while nexts.count < count, let last = nexts.last {
            let more = nextPaydays(for: anchor, count: 4, from: last, using: cal)
            if more.isEmpty { break }
            nexts.append(contentsOf: more)
        }

        let bounds = [prev] + nexts
        let limit = min(count, max(0, bounds.count - 1))

        var periods: [CombinedPeriod] = []
        for i in 0..<limit {
            let start = bounds[i]
            let end = bounds[i + 1]

            let incomes: [PeriodIncome] = allSchedules.compactMap { sch in
                guard paysOn(end, schedule: sch, cal: cal),
                      let src = sch.source else { return nil }
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
                   let src = sch.source {
                    return PeriodIncome(source: src, amount: src.defaultAmount)
                }
                return nil
            }

            periods.append(.init(start: prev, end: next, payday: next, incomes: incomes))
            if periods.count >= count { break }
        }

        // Extend if needed
        if periods.count < count, let lastEnd = periods.last?.end {
            var tail: Set<Date> = []
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
                       let src = sch.source {
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
        @unknown default:
            return nil
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
            let d = stripTime(sch.anchorDate, cal: cal)
            return d >= stripTime(lower, cal: cal) ? [d] : []
        case .weekly:
            return strideDays(anchor: sch.anchorDate, every: 7, atOrAfter: lower, count: count, cal: cal)
        case .biweekly:
            return strideDays(anchor: sch.anchorDate, every: 14, atOrAfter: lower, count: count, cal: cal)
        case .monthly:
            let day = cal.component(.day, from: sch.anchorDate)
            return strideMonthly(anchor: sch.anchorDate, day: day, atOrAfter: lower, count: count, cal: cal)
        case .semimonthly:
            return strideSemiMonthly(anchor: sch.anchorDate, d1: sch.semimonthlyFirstDay, d2: sch.semimonthlySecondDay, atOrAfter: lower, count: count, cal: cal)
        @unknown default:
            return []
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
            if let delta = cal.dateComponents([.day], from: a, to: d).day { return delta >= 0 && delta % 7 == 0 }
            return false
        case .biweekly:
            if let delta = cal.dateComponents([.day], from: a, to: d).day { return delta >= 0 && delta % 14 == 0 }
            return false
        case .monthly:
            let anchorDay = max(1, min(28, cal.component(.day, from: a)))
            return cal.component(.day, from: d) == anchorDay
        case .semimonthly:
            let ad1 = max(1, min(28, sch.semimonthlyFirstDay))
            let ad2 = max(1, min(28, sch.semimonthlySecondDay))
            let dd = cal.component(.day, from: d)
            return dd == ad1 || dd == ad2
        @unknown default:
            return false
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

        // advance to the first occurrence >= lower
        while d < lower {
            guard let nd = cal.date(byAdding: .day, value: days, to: d) else { break }
            d = nd
        }
        // collect
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
        // start from the 1st of the month for `lower`
        let startMonth = firstOfMonth(for: lower, cal: cal)
        var cursor = startMonth
        var out: [Date] = []

        while out.count < count {
            if let candidate = cal.date(bySetting: .day, value: dayClamped, of: cursor) {
                let c = stripTime(candidate, cal: cal)
                if c >= stripTime(lower, cal: cal) { out.append(c) }
            }
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
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
        let startMonth = firstOfMonth(for: lower, cal: cal)
        var cursor = startMonth
        var out: [Date] = []

        while out.count < count {
            for dd in days {
                if let candidate = cal.date(bySetting: .day, value: dd, of: cursor) {
                    let c = stripTime(candidate, cal: cal)
                    if c >= stripTime(lower, cal: cal) {
                        out.append(c)
                        if out.count >= count { break }
                    }
                }
            }
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
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
        let thisMonth = firstOfMonth(for: lower, cal: cal)
        if let candidate = cal.date(bySetting: .day, value: day, of: thisMonth) {
            let c = stripTime(candidate, cal: cal)
            if c <= stripTime(lower, cal: cal) { return c }
        }
        if let prevMonth = cal.date(byAdding: .month, value: -1, to: thisMonth),
           let candidate = cal.date(bySetting: .day, value: day, of: prevMonth) {
            return stripTime(candidate, cal: cal)
        }
        return nil
    }

    private static func semiMonthlyBackwards(anchor: Date, d1: Int, d2: Int, atOrBefore lower: Date, cal: Calendar) -> Date? {
        let days = [max(1, min(28, d1)), max(1, min(28, d2))].sorted()
        let thisMonth = firstOfMonth(for: lower, cal: cal)

        var candidates: [Date] = []
        for dd in days {
            if let candidate = cal.date(bySetting: .day, value: dd, of: thisMonth) {
                let c = stripTime(candidate, cal: cal)
                if c <= stripTime(lower, cal: cal) { candidates.append(c) }
            }
        }
        if let best = candidates.max() { return best }

        if let prevMonth = cal.date(byAdding: .month, value: -1, to: thisMonth) {
            candidates.removeAll()
            for dd in days {
                if let candidate = cal.date(bySetting: .day, value: dd, of: prevMonth) {
                    candidates.append(stripTime(candidate, cal: cal))
                }
            }
            return candidates.max()
        }
        return nil
    }

    // MARK: - Helpers

    private static func firstOfMonth(for d: Date, cal: Calendar) -> Date {
        let comps = cal.dateComponents([.year, .month], from: d)
        return cal.date(from: comps).map { cal.startOfDay(for: $0) } ?? cal.startOfDay(for: d)
    }

    private static func stripTime(_ d: Date, cal: Calendar) -> Date {
        cal.startOfDay(for: d)
    }
}

// MARK: - Notifications-friendly helpers

extension CombinedPayEventsEngine {
    /// Build **upcoming** breakdowns (periods + bills allocated) for notifications/badges.
    /// Start from `from` (default now), return `count` periods forward.
    @MainActor
    static func upcomingBreakdowns(
        context: ModelContext,
        count: Int,
        from: Date = .now,
        calendar: Calendar = .current
    ) -> [CombinedBreakdown] {
        // Fetch inputs
        let schedules: [IncomeSchedule] = (try? context.fetch(FetchDescriptor<IncomeSchedule>())) ?? []
        let bills: [Bill] = (try? context.fetch(FetchDescriptor<Bill>())) ?? []

        // Build periods then allocate bills
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: max(1, count),
            from: from,
            using: calendar
        )
        return SafeAllocationEngine.allocate(bills: bills, into: periods, calendar: calendar)
    }

    /// Alias to match older call sites used in NotifyKeys.swift.
    @MainActor
    static func combinedBreakdownsForUpcoming(
        context: ModelContext,
        count: Int,
        from: Date = .now,
        calendar: Calendar = .current
    ) -> [CombinedBreakdown] {
        upcomingBreakdowns(context: context, count: count, from: from, calendar: calendar)
    }
}
