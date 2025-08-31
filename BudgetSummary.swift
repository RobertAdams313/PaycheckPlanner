//
//  BudgetSummary.swift
//  Paycheck Planner
//
//  Created by Rob on 8/28/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  PeriodSummary.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  © 2025 Rob Adams. All rights reserved.
//

//
//  PeriodSummary.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  © 2025 Rob Adams. All rights reserved.
//

import Foundation

// MARK: - Types

struct BudgetSummary {
    let period: DateInterval
    let bills: [Bill]
    let totalBills: Decimal
    /// Remaining = income - totalBills + rollover (carry over +/−)
    let remaining: Decimal
}

enum BudgetEngine {
    // MARK: - Decimal helpers

    /// Convert Double to Decimal safely (no ambiguous initializer issues)
    @inline(__always)
    private static func dec(_ value: Double) -> Decimal {
        NSDecimalNumber(value: value).decimalValue
    }

    @inline(__always)
    private static var zero: Decimal { .zero }

    // MARK: - Filtering

    static func billsForPeriod(_ interval: DateInterval, from all: [Bill], calendar: Calendar = .current) -> [Bill] {
        Bill.bills(in: interval, from: all, calendar: calendar)
            .sorted { $0.dueDate < $1.dueDate }
    }

    static func total(for bills: [Bill]) -> Decimal {
        bills.reduce(zero) { partial, bill in
            partial + dec(bill.amount)   // <-- FIX: convert Double -> Decimal
        }
    }

    // MARK: - Single summary

    static func summarize(
        period: DateInterval,
        allBills: [Bill],
        income: Decimal,
        rollover: Decimal,
        calendar: Calendar = .current
    ) -> BudgetSummary {
        let inPeriod = billsForPeriod(period, from: allBills, calendar: calendar)
        let totalBills = total(for: inPeriod)
        let remaining = income - totalBills + rollover
        return BudgetSummary(period: period, bills: inPeriod, totalBills: totalBills, remaining: remaining)
    }

    // Overloads

    static func summarize(
        period: DateInterval,
        bills: [Bill],
        income: Decimal,
        rollover: Decimal,
        calendar: Calendar = .current
    ) -> BudgetSummary {
        summarize(period: period, allBills: bills, income: income, rollover: rollover, calendar: calendar)
    }

    static func summarize(
        period: DateInterval,
        allBills: [Bill],
        income: Double,
        rollover: Double,
        calendar: Calendar = .current
    ) -> BudgetSummary {
        summarize(period: period,
                  allBills: allBills,
                  income: dec(income),
                  rollover: dec(rollover),
                  calendar: calendar)
    }

    // MARK: - Multiple summaries

    static func summaries(
        for periods: [DateInterval],
        allBills: [Bill],
        income: Decimal,
        initialRollover: Decimal,
        calendar: Calendar = .current
    ) -> [BudgetSummary] {
        var rollover = initialRollover
        var results: [BudgetSummary] = []
        for p in periods {
            let s = summarize(period: p, allBills: allBills, income: income, rollover: rollover, calendar: calendar)
            results.append(s)
            rollover = nextRollover(from: s.remaining)
        }
        return results
    }

    static func summaries(
        for periods: [DateInterval],
        allBills: [Bill],
        income: Double,
        initialRollover: Double,
        calendar: Calendar = .current
    ) -> [BudgetSummary] {
        summaries(for: periods,
                  allBills: allBills,
                  income: dec(income),
                  initialRollover: dec(initialRollover),
                  calendar: calendar)
    }

    // Arrays of incomes
    static func summaries(
        for periods: [DateInterval],
        allBills: [Bill],
        incomes: [Decimal],
        initialRollover: Decimal,
        calendar: Calendar = .current
    ) -> [BudgetSummary] {
        var rollover = initialRollover
        var results: [BudgetSummary] = []
        let count = min(periods.count, incomes.count)
        for i in 0..<count {
            let s = summarize(period: periods[i],
                              allBills: allBills,
                              income: incomes[i],
                              rollover: rollover,
                              calendar: calendar)
            results.append(s)
            rollover = nextRollover(from: s.remaining)
        }
        return results
    }

    static func summaries(
        for periods: [DateInterval],
        allBills: [Bill],
        incomes: [Double],
        initialRollover: Double,
        calendar: Calendar = .current
    ) -> [BudgetSummary] {
        summaries(for: periods,
                  allBills: allBills,
                  incomes: incomes.map(dec),
                  initialRollover: dec(initialRollover),
                  calendar: calendar)
    }

    // MARK: - Rollover

    static func nextRollover(from currentRemaining: Decimal) -> Decimal {
        currentRemaining
    }

    // MARK: - PlanView convenience

    static func summaries(
        for source: Any,
        bills: [Bill],
        count: Int,
        income: Decimal = .zero,
        initialRollover: Decimal = .zero,
        calendar: Calendar = .current
    ) -> [BudgetSummary] {
        let periods = buildPayPeriods(from: source, count: count, calendar: calendar)

        let reflectedIncome: Decimal = {
            if income != .zero { return income }
            if let s = source as? IncomeSource { return dec(s.amount) }
            let mirror = Mirror(reflecting: source)
            for child in mirror.children {
                let key = child.label?.lowercased() ?? ""
                if key == "amount" || key.contains("income") {
                    if let d = child.value as? Double { return dec(d) }
                    if let decVal = child.value as? Decimal { return decVal }
                }
            }
            return .zero
        }()

        return summaries(for: periods,
                         allBills: bills,
                         income: reflectedIncome,
                         initialRollover: initialRollover,
                         calendar: calendar)
    }

    // MARK: - Period builder

    private static func buildPayPeriods(from source: Any, count: Int, calendar: Calendar) -> [DateInterval] {
        let mirror = Mirror(reflecting: source)

        let anchor: Date = {
            for child in mirror.children {
                if let date = child.value as? Date {
                    let label = child.label?.lowercased() ?? ""
                    if label.contains("anchor") || label.contains("start") {
                        return date
                    }
                }
            }
            return Date()
        }()

        let frequency: RepeatFrequency = {
            for child in mirror.children {
                let label = child.label?.lowercased() ?? ""
                if label.contains("frequency") || label.contains("repeat") {
                    if let freq = child.value as? RepeatFrequency { return freq }
                    if let s = child.value as? String { return RepeatFrequency(fuzzy: s) }
                }
            }
            return .biweekly
        }()

        return nextPayPeriods(from: anchor, frequency: frequency, count: max(count, 0), calendar: calendar)
    }

    private static func nextPayPeriods(from anchor: Date, frequency: RepeatFrequency, count: Int, calendar: Calendar) -> [DateInterval] {
        guard count > 0 else { return [] }
        var intervals: [DateInterval] = []
        var start = anchor
        switch frequency {
        case .none:
            for _ in 0..<count {
                intervals.append(DateInterval(start: start, end: start))
                start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            }
        case .weekly:
            for _ in 0..<count {
                let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                intervals.append(DateInterval(start: start, end: end))
                start = end
            }
        case .biweekly:
            for _ in 0..<count {
                let end = calendar.date(byAdding: .day, value: 14, to: start) ?? start
                intervals.append(DateInterval(start: start, end: end))
                start = end
            }
        case .monthly:
            for _ in 0..<count {
                let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                intervals.append(DateInterval(start: start, end: end))
                start = end
            }
        case .yearly:
            for _ in 0..<count {
                let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
                intervals.append(DateInterval(start: start, end: end))
                start = end
            }
        }
        return intervals
    }
}
