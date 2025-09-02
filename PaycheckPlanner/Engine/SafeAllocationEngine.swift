//
//  SafeAllocationEngine.swift
//  PaycheckPlanner
//
//  Built off the user’s existing engine: keeps types, adds carry-over toggle respect,
//  clamps before anchorDueDate, and stops at optional recurrence endDate.
//

import Foundation
import SwiftData

// MARK: - Bill line items (internal)

struct AllocatedBillLine: Identifiable, Hashable {
    let id = UUID()
    let bill: Bill
    let occurrences: Int
    let amountEach: Decimal
    var total: Decimal { amountEach * Decimal(occurrences) }
}

// MARK: - Combined breakdown with carry-forward

struct CombinedBreakdown: Identifiable, Hashable {
    let id = UUID()
    let period: CombinedPeriod
    let items: [AllocatedBillLine]

    /// Carry-in from the previous period (can be negative).
    let carryIn: Decimal

    var billsTotal: Decimal { items.reduce(0) { $0 + $1.total } }
    var incomeTotal: Decimal { period.incomeTotal }

    /// Remaining after carry-in is applied for this period.
    var leftover: Decimal { incomeTotal + carryIn - billsTotal }

    /// Next period’s carry-in.
    var carryOut: Decimal { leftover }
}

// MARK: - Engine

enum SafeAllocationEngine {

    // MARK: Allocate bills into periods (carry-over aware)
    //
    // NOTE: We default `carryOverEnabled` to the stored preference so call sites don’t need to change.
    // Reads @AppStorage("carryoverEnabled") via UserDefaults at call time.
    static func allocate(
        bills: [Bill],
        into periods: [CombinedPeriod],
        calendar cal: Calendar = .init(identifier: .gregorian),
        carryOverEnabled: Bool = (UserDefaults.standard.object(forKey: "carryoverEnabled") as? Bool) ?? true
    ) -> [CombinedBreakdown] {

        let ordered = periods.sorted { $0.start < $1.start }

        var results: [CombinedBreakdown] = []
        var runningCarry: Decimal = 0

        for p in ordered {
            let items: [AllocatedBillLine] = bills.compactMap { bill in
                // Skip inactive bills early if you are using the flag.
                if bill.active == false { return nil }

                let n = dueOccurrences(of: bill, in: p.start, p.end, cal: cal)
                return n > 0 ? AllocatedBillLine(bill: bill, occurrences: n, amountEach: bill.amount) : nil
            }

            // Respect the toggle: feed the previous period’s carry only when enabled.
            let carryIn = carryOverEnabled ? runningCarry : 0
            let breakdown = CombinedBreakdown(period: p, items: items, carryIn: carryIn)

            // Only propagate when enabled; otherwise, reset between periods.
            runningCarry = carryOverEnabled ? breakdown.carryOut : 0

            results.append(breakdown)
        }

        return results
    }

    // MARK: - Helpers

    /// Count how many times a bill is due in [start, end).
    ///
    /// Rules:
    /// - Never schedule before `bill.anchorDueDate` (clamp lower bound).
    /// - If `bill.endDate` is set, do not schedule on/after the day after `endDate`
    ///   (i.e., last valid due is strictly < startOfDay(endDate)+1d).
    private static func dueOccurrences(
        of bill: Bill,
        in start: Date,
        _ end: Date,
        cal: Calendar
    ) -> Int {
        // Clamp lower bound to anchor day (no occurrences before anchor)
        let anchor = cal.startOfDay(for: bill.anchorDueDate)
        var lower = max(cal.startOfDay(for: start), anchor)

        // Clamp upper bound to day-after endDate if provided
        var upper = end
        if let until = bill.endDate {
            let dayAfter = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: until)) ?? until
            upper = min(upper, dayAfter)
        }

        if upper <= lower { return 0 }

        switch bill.recurrence {
        case .once:
            let due = cal.startOfDay(for: bill.anchorDueDate)
            return (due >= lower && due < upper) ? 1 : 0

        case .weekly:
            return countWeeklyOccurrences(
                anchor: anchor, lower: lower, upper: upper, stepDays: 7, cal: cal
            )

        case .biweekly:
            return countWeeklyOccurrences(
                anchor: anchor, lower: lower, upper: upper, stepDays: 14, cal: cal
            )

        case .monthly:
            let day = cal.component(.day, from: bill.anchorDueDate)
            return countMonthlyOccurrences(
                daysInMonth: [day], lower: lower, upper: upper, cal: cal
            )

        case .semimonthly:
            // With no per-bill day fields, default to the common 1st & 15th pattern.
            return countMonthlyOccurrences(
                daysInMonth: [1, 15], lower: lower, upper: upper, cal: cal
            )
        }
    }

    // MARK: Weekly/Biweekly

    private static func countWeeklyOccurrences(
        anchor: Date,
        lower: Date,
        upper: Date,
        stepDays: Int,
        cal: Calendar
    ) -> Int {
        let lowerDay = cal.startOfDay(for: lower)
        let anchorDay = cal.startOfDay(for: anchor)

        // Find the first occurrence on or after `lowerDay`
        let diff = cal.dateComponents([.day], from: anchorDay, to: lowerDay).day ?? 0
        // Normalize diff to positive modulo
        let mod = ((diff % stepDays) + stepDays) % stepDays
        let offset = (mod == 0) ? 0 : (stepDays - mod)
        guard let first = cal.date(byAdding: .day, value: offset, to: lowerDay) else { return 0 }
        if first >= upper { return 0 }

        let span = cal.dateComponents([.day], from: first, to: upper).day ?? 0
        if span <= 0 { return 1 } // first < upper implies at least one
        // Count occurrences where first + k*step < upper
        return 1 + (span - 1) / stepDays
    }

    // MARK: Monthly/Semimonthly

    private static func countMonthlyOccurrences(
        daysInMonth: [Int],
        lower: Date,
        upper: Date,
        cal: Calendar
    ) -> Int {
        var count = 0

        // Walk months from the month containing `lower` until we cross `upper`.
        var comps = cal.dateComponents([.year, .month], from: lower)
        while true {
            guard let y = comps.year, let m = comps.month else { break }

            // Construct dates for requested days, clamped to month length.
            var anyInThisMonth = false
            for d in daysInMonth {
                var dc = DateComponents()
                dc.year = y
                dc.month = m

                // Clamp `d` to the last day of this month.
                if let monthDate = cal.date(from: DateComponents(year: y, month: m)),
                   let rng = cal.range(of: .day, in: .month, for: monthDate) {
                    dc.day = min(max(1, d), rng.count)
                } else {
                    dc.day = d
                }

                if let candidate = cal.date(from: dc) {
                    let cand = cal.startOfDay(for: candidate)
                    if cand >= lower && cand < upper {
                        count += 1
                        anyInThisMonth = true
                    }
                }
            }

            // Advance to the first day of next month; stop once we’ve crossed upper.
            comps.month = (comps.month ?? 1) + 1
            guard let nextMonth = cal.date(from: comps) else { break }
            if nextMonth >= upper { break }
            // Shift `lower` up as we progress to avoid recounting.
            // (Not strictly necessary, but keeps comparisons tight.)
        }

        return count
    }
}
