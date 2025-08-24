//
//  IncomeSchedule.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation
import SwiftData

/// Per-income pay schedule without disturbing your existing PaySchedule.
/// Each IncomeSource can have its own schedule here.
@Model
final class IncomeSchedule {
    @Relationship(deleteRule: .cascade) var source: IncomeSource?
    var frequency: PayFrequency
    var anchorDate: Date
    var semimonthlyFirstDay: Int
    var semimonthlySecondDay: Int

    init(
        source: IncomeSource? = nil,
        frequency: PayFrequency = .biweekly,
        anchorDate: Date = .now,
        semimonthlyFirstDay: Int = 1,
        semimonthlySecondDay: Int = 15
    ) {
        self.source = source
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.semimonthlyFirstDay = semimonthlyFirstDay
        self.semimonthlySecondDay = semimonthlySecondDay
    }
}
