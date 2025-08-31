//
//  IncomeSource.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation
import SwiftData

@Model
final class IncomeSource {
    @Attribute(.unique) var id: UUID
    var name: String

    // Anchor date defines the first paycheck; frequency defines the recurrence (drives periods)
    var anchorDate: Date
    var frequency: RepeatFrequency

    // Use Decimal for money, mark as transformable (Codable) for SwiftData
    @Attribute(.transformable(by: .codable)) var baseIncome: Decimal

    init(
        id: UUID = UUID(),
        name: String,
        anchorDate: Date,
        frequency: RepeatFrequency,
        baseIncome: Decimal
    ) {
        self.id = id
        self.name = name
        self.anchorDate = anchorDate
        self.frequency = frequency
        self.baseIncome = baseIncome
    }
}
