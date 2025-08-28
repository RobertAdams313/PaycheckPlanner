//
//  BudgetEngineTests.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import XCTest
@testable import PaycheckPlanner

final class BudgetEngineTests: XCTestCase {

    func makeIncome(name: String = "Main",
                    amount: Double = 1000,
                    frequency: String = "biweekly",
                    start: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> IncomeSource {
        IncomeSource(name: name, amount: amount, frequency: frequency, startDate: start)
    }

    func makeBill(name: String, amount: Double, due: Date) -> Bill {
        Bill(name: name, amount: amount, dueDate: due, repeatFrequency: "one-time")
    }

    func testCarryForwardRemainingAndShortfall() {
        // Period 1: paycheck 1000, bills 700 => remaining +300 carry to P2
        // Period 2: paycheck 1000 + carry 300, bills 1600 => remaining -300 carry to P3
        // Period 3: paycheck 1000 + carry -300, bills 200 => remaining +500
        let start = Date(timeIntervalSince1970: 1_700_000_000) // fixed anchor
        let income = makeIncome(start: start)

        let p1Start = start
        let p2Start = Calendar.current.date(byAdding: .day, value: 14, to: p1Start)! // biweekly
        let p3Start = Calendar.current.date(byAdding: .day, value: 28, to: p1Start)!

        let bills = [
            makeBill(name: "Rent", amount: 700, due: p1Start.addingTimeInterval(86400*2)),
            makeBill(name: "LargeThing", amount: 1600, due: p2Start.addingTimeInterval(86400*2)),
            makeBill(name: "Tiny", amount: 200, due: p3Start.addingTimeInterval(86400*3))
        ]

        let summaries = BudgetEngine.summaries(for: income, bills: bills, count: 3)
        XCTAssertEqual(summaries.count, 3)

        // P1
        XCTAssertEqual(summaries[0].paycheckAmount, 1000, accuracy: 0.001)
        XCTAssertEqual(summaries[0].billsUsed, 700, accuracy: 0.001)
        XCTAssertEqual(summaries[0].carryIn, 0, accuracy: 0.001)
        XCTAssertEqual(summaries[0].remaining, 300, accuracy: 0.001)

        // P2
        XCTAssertEqual(summaries[1].carryIn, 300, accuracy: 0.001)
        XCTAssertEqual(summaries[1].billsUsed, 1600, accuracy: 0.001)
        XCTAssertEqual(summaries[1].remaining, -300, accuracy: 0.001)

        // P3
        XCTAssertEqual(summaries[2].carryIn, -300, accuracy: 0.001)
        XCTAssertEqual(summaries[2].billsUsed, 200, accuracy: 0.001)
        XCTAssertEqual(summaries[2].remaining, 500, accuracy: 0.001)
    }

    func testPeriodMathWeeklyAndMonthly() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        // weekly
        let incomeWeekly = IncomeSource(name: "W", amount: 100, frequency: "weekly", startDate: start)
        let weeklyDates = Schedule.nextPayDates(from: start, frequency: "weekly", count: 3)
        XCTAssertEqual(weeklyDates.count, 3)
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: weeklyDates[0], to: weeklyDates[1]).day, 7)

        // monthly
        let incomeMonthly = IncomeSource(name: "M", amount: 100, frequency: "monthly", startDate: start)
        let monthlyDates = Schedule.nextPayDates(from: start, frequency: "monthly", count: 2)
        XCTAssertEqual(monthlyDates.count, 2)
        XCTAssertNotNil(incomeMonthly) // silence warning
    }
}
