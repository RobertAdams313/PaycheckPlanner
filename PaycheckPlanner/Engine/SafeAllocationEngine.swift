//
//  AllocatedBillLine.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

//
//  SafeAllocationEngine.swift
//  PaycheckPlanner
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

    /// Allocate bills into periods and apply carry-forward across them.
    /// IMPORTANT: We treat period bounds as **[start, end)** (start-inclusive, end-exclusive),
    /// so a bill due **on** the payday/start date is counted in this new period.
    static func allocate(
        bills: [Bill],
        into periods: [CombinedPeriod],
        calendar cal: Calendar = .init(identifier: .gregorian)
    ) -> [CombinedBreakdown] {

        let ordered = periods.sorted { $0.start < $1.start }

        var results: [CombinedBreakdown] = []
        var runningCarry: Decimal = 0

        for p in ordered {
            let items: [AllocatedBillLine] = bills.compactMap { bill in
                let n = dueOccurrences(of: bill, in: p.start, p.end, cal: cal)
                return n > 0 ? AllocatedBillLine(bill: bill, occurrences: n, amountEach: bill.amount) : nil
            }
            let breakdown = CombinedBreakdown(period: p, items: items, carryIn: runningCarry)
            runningCarry = breakdown.carryOut
            results.append(breakdown)
        }

        return results
    }

    // MARK: - Recurrence math (start-inclusive, end-exclusive)

    private static func dueOccurrences(of bill: Bill, in start: Date, _ end: Date, cal: Calendar) -> Int {
        guard end > start else { return 0 }
        switch bill.recurrence {
        case .once:
            // include if due date is in [start, end)
            return (bill.anchorDueDate >= start && bill.anchorDueDate < end) ? 1 : 0

        case .weekly:
            return strideCount(from: bill.anchorDueDate, everyDays: 7, in: start, end, cal: cal)

        case .biweekly:
            return strideCount(from: bill.anchorDueDate, everyDays: 14, in: start, end, cal: cal)

        case .monthly:
            return monthlyCount(anchor: bill.anchorDueDate, in: start, end, cal: cal)

        case .semimonthly:
            let aDay = cal.component(.day, from: bill.anchorDueDate)
            let (d1, d2) = aDay <= 15 ? (max(1, min(28, aDay)), 30) : (1, max(1, min(28, aDay)))
            return semiMonthlyCount(d1: d1, d2: d2, in: start, end, cal: cal)
        }
    }

    private static func strideCount(from anchor: Date, everyDays: Int, in start: Date, _ end: Date, cal: Calendar) -> Int {
        // Move forward to the first occurrence **>= start** (not strictly greater).
        var d = anchor
        while d < start {
            d = cal.date(byAdding: .day, value: everyDays, to: d)
                ?? d.addingTimeInterval(Double(everyDays) * 86400)
        }
        var n = 0
        // Count occurrences while d is **< end** (end-exclusive)
        while d < end {
            n += 1
            d = cal.date(byAdding: .day, value: everyDays, to: d)
                ?? d.addingTimeInterval(Double(everyDays) * 86400)
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
            if let d = cal.date(from: c), d >= start && d < end { n += 1 }   // start-inclusive, end-exclusive
            comps.month = m + 1
            if (cal.date(from: comps) ?? end) >= end { break }
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
                if let d = cal.date(from: c), d >= start && d < end { n += 1 } // start-inclusive, end-exclusive
            }
            comps.month = m + 1
            if (cal.date(from: comps) ?? end) >= end { break }
        }
        return n
    }
}

