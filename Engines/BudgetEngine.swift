//
//  PeriodSummary.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation

struct PeriodSummary: Identifiable, Hashable {
    var id: UUID = UUID()
    let periodStart: Date
    let periodEnd: Date
    let paycheckAmount: Double
    let billsUsed: Double
    let carryIn: Double         // from previous period (+credit / -debt)
    var remaining: Double { (paycheckAmount + carryIn) - billsUsed }
    var carryOut: Double { remaining } // what flows to the next period
}

enum BudgetEngine {
    static func summaries(for source: IncomeSource, bills: [Bill], count: Int = 6) -> [PeriodSummary] {
        let payDates = Schedule.nextPayDates(from: source.startDate, frequency: source.frequency, count: count)
        var results: [PeriodSummary] = []
        var carry: Double = 0

        for payStart in payDates {
            let start = DateUtils.startOfDay(payStart)
            let end = Schedule.periodEnd(for: start, frequency: source.frequency)
            let used = bills
                .filter { DateUtils.inRange($0.dueDate, start, end) }
                .reduce(0) { $0 + $1.amount }

            let summary = PeriodSummary(
                periodStart: start,
                periodEnd: end,
                paycheckAmount: source.amount,
                billsUsed: used,
                carryIn: carry
            )
            results.append(summary)
            carry = summary.carryOut // propagate Remaining (pos or neg) forward
        }
        return results
    }
}
