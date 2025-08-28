//
//  IncomeMaterializer.swift
//  PaycheckPlanner
//

import Foundation
import SwiftData

/// Bridges SwiftData models to `[Income]` for projection.
enum IncomeMaterializer {
    static func incomes(from sources: [IncomeSource], calendar: Calendar = .current) -> [Income] {
        sources.flatMap { src in
            guard let sch = src.schedule else { return [] }
            return incomes(from: sch, named: src.name, amountPerPay: src.defaultAmount, calendar: calendar)
        }
    }

    static func incomes(from schedules: [IncomeSchedule], calendar: Calendar = .current) -> [Income] {
        schedules.flatMap { sch in
            guard let src = sch.source else { return [] }
            return incomes(from: sch, named: src.name, amountPerPay: src.defaultAmount, calendar: calendar)
        }
    }

    private static func incomes(from sch: IncomeSchedule,
                                named name: String,
                                amountPerPay: Decimal,
                                calendar: Calendar) -> [Income] {
        switch sch.frequency {
        case .weekly:
            return [Income(name: name, amount: amountPerPay, frequency: .weekly,
                           startDate: calendar.startOfDay(for: sch.anchorDate))]
        case .biweekly:
            return [Income(name: name, amount: amountPerPay, frequency: .biweekly,
                           startDate: calendar.startOfDay(for: sch.anchorDate))]
        case .monthly:
            let dom = calendar.component(.day, from: sch.anchorDate)
            let anchored = adjustToDayOfMonth(base: sch.anchorDate, desiredDay: dom, calendar: calendar)
            return [Income(name: name, amount: amountPerPay, frequency: .monthly, startDate: anchored)]
        case .semimonthly:
            // Represent as two monthly incomes, each full per-pay amount.
            let d1 = clampDay(sch.semimonthlyFirstDay), d2 = clampDay(sch.semimonthlySecondDay)
            let a1 = adjustToDayOfMonth(base: sch.anchorDate, desiredDay: d1, calendar: calendar)
            let a2 = adjustToDayOfMonth(base: sch.anchorDate, desiredDay: d2, calendar: calendar)
            return [
                Income(name: name, amount: amountPerPay, frequency: .monthly, startDate: a1),
                Income(name: name, amount: amountPerPay, frequency: .monthly, startDate: a2)
            ]
        }
    }

    private static func clampDay(_ d: Int) -> Int { max(1, min(28, d)) }
    private static func adjustToDayOfMonth(base: Date, desiredDay: Int, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: base)
        comps.day = clampDay(desiredDay)
        return calendar.startOfDay(for: calendar.date(from: comps) ?? base)
    }
}
