//
//  SafeAllocationEngine.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated by ChatGPT on 8/25/25 – Added rollover (surplus & shortfall) + running balance per period.
//  Copyright © 2025 Rob Adams. All rights reserved.
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

// MARK: - Allocation result
// Stored properties so results reflect rollover-aware totals for UI.
struct CombinedBreakdown: Identifiable, Hashable {
    let id = UUID()
    let period: CombinedPeriod          // carries raw period.incomeTotal (without rollover)
    let items: [AllocatedBillLine]

    /// Income available this period including rollover entering this period.
    let incomeTotal: Decimal
    /// Total of bills due within this period window.
    let billsTotal: Decimal
    /// Surplus(+) or shortfall(−) for this period.
    let leftover: Decimal
    /// Cumulative balance *after* this period (i.e., what rolls into the next period).
    /// This equals `leftover` when starting from zero, but kept explicit for clarity and future extensions.
    let runningBalance: Decimal
}

// MARK: - Engine

enum SafeAllocationEngine {

    /// Allocates bills into periods while carrying forward any leftover (positive)
    /// or shortfall (negative) into the next period.
    ///
    /// Rollover math:
    ///   R_0 = 0
    ///   effectiveIncome_n = period.incomeTotal + R_{n-1}
    ///   leftover_n = effectiveIncome_n - billsTotal_n
    ///   R_n = leftover_n  // can be positive (surplus) or negative (debt)
    static func allocate(
        bills: [Bill],
        into periods: [CombinedPeriod],
        calendar cal: Calendar = .init(identifier: .gregorian)
    ) -> [CombinedBreakdown] {
        var results: [CombinedBreakdown] = []
        var rollover: Decimal = 0 // surplus (+) or debt (−) entering the current period

        for p in periods {
            // Build period items (what is due inside this period)
            let items: [AllocatedBillLine] = bills.compactMap { bill in
                let n = dueOccurrences(of: bill, in: p.start, p.end, cal: cal)
                return n > 0 ? AllocatedBillLine(bill: bill, occurrences: n, amountEach: bill.amount) : nil
            }

            let billsTotal = items.reduce(0) { $0 + $1.total }
            let effectiveIncome = p.incomeTotal + rollover
            let leftover = effectiveIncome - billsTotal
            let runningBalance = leftover // balance *after* this check, rolls into next

            results.append(
                CombinedBreakdown(
                    period: p,
                    items: items,
                    incomeTotal: effectiveIncome,
                    billsTotal: billsTotal,
                    leftover: leftover,
                    runningBalance: runningBalance
                )
            )

            // Carry surplus or shortfall forward (allow negative)
            rollover = runningBalance
        }

        return results
    }

    // MARK: - Recurrence math (unchanged)

    private static func dueOccurrences(of bill: Bill, in start: Date, _ end: Date, cal: Calendar) -> Int {
        guard end > start else { return 0 }
        switch bill.recurrence {
        case .once:
            return (bill.anchorDueDate > start && bill.anchorDueDate <= end) ? 1 : 0
        case .weekly:
            return strideCount(from: bill.anchorDueDate, everyDays: 7, in: start, end, cal: cal)
        case .biweekly:
            return strideCount(from: bill.anchorDueDate, everyDays: 14, in: start, end, cal: cal)
        case .monthly:
            return monthlyCount(anchor: bill.anchorDueDate, in: start, end, cal: cal)
        case .semimonthly:
            let aDay = cal.component(.day, from: bill.anchorDueDate)
            let (d1, d2) = aDay <= 15 ? (aDay, 30) : (1, aDay)
            return semiMonthlyCount(d1: d1, d2: d2, in: start, end, cal: cal)
        }
    }

    private static func strideCount(from anchor: Date, everyDays: Int, in start: Date, _ end: Date, cal: Calendar) -> Int {
        var d = anchor
        while d <= start {
            d = cal.date(byAdding: .day, value: everyDays, to: d) ?? d.addingTimeInterval(Double(everyDays) * 86400)
        }
        var n = 0
        while d <= end {
            n += 1
            d = cal.date(byAdding: .day, value: everyDays, to: d) ?? d.addingTimeInterval(Double(everyDays) * 86400)
        }
        return n
    }

    private static func monthlyCount(anchor: Date, in start: Date, _ end: Date, cal: Calendar) -> Int {
        let day = max(1, min(28, cal.component(.day, from: anchor)))
        var comps = cal.dateComponents([.year, .month], from: start)
        var n = 0
        while true {
            guard let y = comps.year, let m = comps.month else { break }
            var c = DateComponents(); c.year = y; c.month = m; c.day = day
            if let d = cal.date(from: c), d > start && d <= end { n += 1 }
            comps.month = m + 1
            if (cal.date(from: comps) ?? end) > end { break }
        }
        return n
    }

    private static func semiMonthlyCount(d1: Int, d2: Int, in start: Date, _ end: Date, cal: Calendar) -> Int {
        let days = [max(1, min(28, d1)), max(1, min(28, d2))].sorted()
        var comps = cal.dateComponents([.year, .month], from: start)
        var n = 0
        while true {
            guard let y = comps.year, let m = comps.month else { break }
            for dd in days {
                var c = DateComponents(); c.year = y; c.month = m; c.day = dd
                if let d = cal.date(from: c), d > start && d <= end { n += 1 }
            }
            comps.month = m + 1
            if (cal.date(from: comps) ?? end) > end { break }
        }
        return n
    }
}
