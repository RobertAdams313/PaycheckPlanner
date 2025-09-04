//
//  PayFrequency.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import Foundation
import SwiftData

// MARK: - Enums

enum PayFrequency: String, Codable, CaseIterable, Identifiable {
    case once, weekly, biweekly, semimonthly, monthly
    var id: String { rawValue }
}

enum BillRecurrence: String, Codable, CaseIterable, Identifiable {
    case once, weekly, biweekly, semimonthly, monthly
    var id: String { rawValue }
}

// MARK: - SwiftData Models
// No @Relationship attributes (let SwiftData infer) unless explicitly provided.
// Defaults use fully qualified initializers to satisfy the macro.

@Model
final class PaySchedule {
    var frequency: PayFrequency = PayFrequency.biweekly
    var anchorDate: Date = Foundation.Date()
    var semimonthlyFirstDay: Int = 1
    var semimonthlySecondDay: Int = 15

    init(
        frequency: PayFrequency = PayFrequency.biweekly,
        anchorDate: Date = Foundation.Date(),
        semimonthlyFirstDay: Int = 1,
        semimonthlySecondDay: Int = 15
    ) {
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.semimonthlyFirstDay = semimonthlyFirstDay
        self.semimonthlySecondDay = semimonthlySecondDay
    }
}

@Model
final class IncomeSchedule {
    @Relationship(deleteRule: .cascade)
    var source: IncomeSource?

    // ✅ Fully qualified defaults (no leading dots)
    var frequency: PayFrequency = PayFrequency.biweekly
    var anchorDate: Date = Date.now
    var semimonthlyFirstDay: Int = 1
    var semimonthlySecondDay: Int = 15

    // ✅ NEW: marks this schedule as the primary grid anchor when selected by the user
    var isMain: Bool = false

    init(
        source: IncomeSource? = nil,
        frequency: PayFrequency = PayFrequency.biweekly,
        anchorDate: Date = Date.now,
        semimonthlyFirstDay: Int = 1,
        semimonthlySecondDay: Int = 15,
        isMain: Bool = false
    ) {
        self.source = source
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.semimonthlyFirstDay = semimonthlyFirstDay
        self.semimonthlySecondDay = semimonthlySecondDay
        self.isMain = isMain
    }
}

@Model
final class IncomeSource {
    var name: String = ""
    var defaultAmount: Decimal = 0
    var variable: Bool = false

    // Remove the inverse here to avoid the circular macro resolution
    @Relationship
    var schedule: IncomeSchedule?

    init(
        name: String = "",
        defaultAmount: Decimal = 0,
        variable: Bool = false,
        schedule: IncomeSchedule? = nil
    ) {
        self.name = name
        self.defaultAmount = defaultAmount
        self.variable = variable
        self.schedule = schedule
    }
}

@Model
final class Bill {
    var name: String = ""
    var amount: Decimal = Foundation.Decimal(0)
    var recurrence: BillRecurrence = BillRecurrence.monthly
    var anchorDueDate: Date = Foundation.Date()

    // Optional category for insights pie chart (e.g., "Rent", "Utilities")
    var category: String = ""

    // Optional recurrence end date. If set, no due dates on/after the day after this date.
    var endDate: Date? = nil

    // Optional activation flag (kept for future UX toggles; defaults to true).
    var active: Bool = true

    init(
        name: String = "",
        amount: Decimal = Foundation.Decimal(0),
        recurrence: BillRecurrence = BillRecurrence.monthly,
        anchorDueDate: Date = Foundation.Date(),
        category: String = "",
        endDate: Date? = nil,
        active: Bool = true
    ) {
        self.name = name
        self.amount = amount
        self.recurrence = recurrence
        self.anchorDueDate = anchorDueDate
        self.category = category
        self.endDate = endDate
        self.active = active
    }
}
