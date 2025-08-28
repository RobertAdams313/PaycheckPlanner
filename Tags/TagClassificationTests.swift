//
//  TagClassificationTests.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import XCTest
@testable import PaycheckPlanner

final class TagClassificationTests: XCTestCase {

    func testKeywordMapping() {
        XCTAssertEqual(PredefinedTags.classify(name: "Verizon Wireless").name, "Phone")
        XCTAssertEqual(PredefinedTags.classify(name: "Netflix").name, "Subscriptions")
        XCTAssertEqual(PredefinedTags.classify(name: "Whole Foods grocery run").name, "Food")
        XCTAssertEqual(PredefinedTags.classify(name: "Random Expense").name, "Misc")
    }

    func testBillInsightsTagRespectsManualCategory() {
        var bill = Bill(name: "Some Insurance", amount: 50, dueDate: .now, repeatFrequency: "monthly", category: "Insurance")
        XCTAssertEqual(bill.insightsTag.name, "Insurance")

        bill.category = ""
        XCTAssertEqual(bill.insightsTag.name, "Insurance", "Keyword should map to Insurance by name")
    }
}
