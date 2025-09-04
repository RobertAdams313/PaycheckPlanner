//
//  CombinedPayEventsEngine.swift
//  PaycheckPlanner
//
//  Overlap fix: default to merged grid when there’s more than one schedule (or only `.once`),
//  and include incomes whose *pay period window* intersects each segment (start, end] (end-inclusive).
//  Also honors a user-selected "main" IncomeSchedule to anchor the primary grid when available.
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

    static func combinedPeriods(
        schedules: [IncomeSchedule],
        count: Int,
        from startFrom: Date = Date.now,
        using cal: Calendar = Calendar(identifier: .gregorian)
    ) -> [CombinedPeriod] {
        guard count > 0 else { return [] }
        let lower = stripTime(startFrom, cal: cal)

        // Prefer an explicitly-marked "main" schedule if it exists and is recurring.
        if let anchor = schedules.first(where: { $0.isMain && $0.frequency != .once }) {
            return periodsUsingAnchor(anchor, allSchedules: schedules, count: count, lower: lower, cal: cal)
        }

        // If there is exactly one recurring schedule, anchor to it.
        if schedules.count == 1, let only = schedules.first, only.frequency != .once {
            return periodsUsingAnchor(only, allSchedules: schedules, count: count, lower: lower, cal: cal)
        }

        // Otherwise, build a merged grid across all paydays.
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
                guard let src = sch.source else { return nil }
                return scheduleOverlapsSegment(sch, start, end, cal: cal)
                    ? PeriodIncome(source: src, amount: src.defaultAmount)
                    : nil
            }

            periods.append(.init(start: start, end: end, payday: end, incomes: incomes))
        }
        return periods
    }

    // MARK: - Merged grid (multiple schedules OR only `.once`)

    private static func periodsUsingMergedGrid(
        schedules: [IncomeSchedule],
        count: Int,
        lower: Date,
        cal: Calendar
    ) -> [CombinedPeriod] {

        var merged: Set<Date> = []
        for sch in schedules {
            if let p = previousPayday(for: sch, atOrBefore: lower, cal: cal) { merged.insert(p) }
            for d in nextPaydays(for: sch, count: count + 2, from: lower, using: cal) { merged.insert(d) }
        }

        var bounds = Array(merged).sorted()
        guard !bounds.isEmpty else { return [] }

        if let first = bounds.first, first > lower {
            if let near = schedules.compactMap({ previousPayday(for: $0, atOrBefore: lower, cal: cal) }).max() {
                bounds.insert(near, at: 0)
            }
        }

        var periods: [CombinedPeriod] = []
        for i in 1..<bounds.count {
            let prev = bounds[i - 1]
            let next = bounds[i]

            let incomes: [PeriodIncome] = schedules.compactMap { sch in
                guard let src = sch.source else { return nil }
                return scheduleOverlapsSegment(sch, prev, next, cal: cal)
                    ? PeriodIncome(source: src, amount: src.defaultAmount)
                    : nil
            }

            periods.append(.init(start: prev, end: next, payday: next, incomes: incomes))
            if periods.count >= count { break }
        }

        // If we came up short, extend tail a bit further.
        if periods.count < count, let lastEnd = periods.last?.end {
            var tail: Set<Date> = []
            for sch in schedules {
                for d in nextPaydays(for: sch, count: count + 4, from: lastEnd, using: cal) { tail.insert(d) }
            }
            let sortedTail = Array(tail).sorted()
            var i = 1
            while periods.count < count && i < sortedTail.count {
                let prev = sortedTail[i - 1]
                let next = sortedTail[i]

                let incomes: [PeriodIncome] = schedules.compactMap { sch in
                    guard let src = sch.source else { return nil }
                    return scheduleOverlapsSegment(sch, prev, next, cal: cal)
                        ? PeriodIncome(source: src, amount: src.defaultAmount)
                        : nil
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
            return semiMonthlyBackwards(
                anchor: sch.anchorDate,
                d1: sch.semimonthlyFirstDay,
                d2: sch.semimonthlySecondDay,
                atOrBefore: lower,
                cal: cal
            )
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
            return strideSemiMonthly(
                anchor: sch.anchorDate,
                d1: sch.semimonthlyFirstDay,
                d2: sch.semimonthlySecondDay,
                atOrAfter: lower,
                count: count,
                cal: cal
            )
        @unknown default:
            return []
        }
    }

    // MARK: - Inclusion helper (end-inclusive)

    /// True if the schedule has a payday inside the segment (start, end].
    /// - (start, end] assigns the exact end-day payday to THIS card and avoids gaps at boundaries.
    private static func scheduleOverlapsSegment(
        _ sch: IncomeSchedule,
        _ segStart: Date,
        _ segEnd: Date,
        cal: Calendar
    ) -> Bool {
        switch sch.frequency {
        case .once:
            let d = cal.startOfDay(for: sch.anchorDate)
            return d > segStart && d <= segEnd

        case .weekly, .biweekly, .monthly, .semimonthly:
            guard let lastPaydayUpToEnd = previousPayday(for: sch, atOrBefore: segEnd, cal: cal) else {
                return false
            }
            // include if its most recent payday up to segEnd is strictly after segStart
            return lastPaydayUpToEnd > segStart

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
        while d < lower { d = cal.date(byAdding: .day, value: days, to: d) ?? d }
        while occurrences.count < count {
            occurrences.append(stripTime(d, cal: cal))
            d = cal.date(byAdding: .day, value: days, to: d) ?? d
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
        let startMonth = firstOfMonth(for: lower, cal: cal)
        var cursor = startMonth
        var out: [Date] = []

        while out.count < count {
            if let candidate = cal.date(bySetting: .day, value: dayClamped, of: cursor) {
                let c = stripTime(candidate, cal: cal)
                if c >= stripTime(lower, cal: cal) { out.append(c) }
            }
            cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
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
            cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
        }
        return out
    }

    // MARK: - Stride helpers (backwards)

    private static func strideBackwardsDays(anchor: Date, every days: Int, atOrBefore lower: Date, cal: Calendar) -> Date? {
        var d = stripTime(anchor, cal: cal)
        if d > lower {
            while d > lower { d = cal.date(byAdding: .day, value: -days, to: d) ?? d }
            return d <= lower ? d : nil
        } else {
            var prev = d
            while d <= lower {
                prev = d
                d = cal.date(byAdding: .day, value: days, to: d) ?? d
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

    /// Helper for semimonthly `previousPayday`.
    private static func semiMonthlyBackwards(
        anchor: Date,
        d1: Int,
        d2: Int,
        atOrBefore lower: Date,
        cal: Calendar
    ) -> Date? {
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
    @MainActor
    static func upcomingBreakdowns(
        context: ModelContext,
        count: Int,
        from: Date = .now,
        calendar: Calendar = .current
    ) -> [CombinedBreakdown] {
        let schedules: [IncomeSchedule] = (try? context.fetch(FetchDescriptor<IncomeSchedule>())) ?? []
        let bills: [Bill] = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: max(1, count),
            from: from,
            using: calendar
        )
        return SafeAllocationEngine.allocate(bills: bills, into: periods, calendar: calendar)
    }

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
