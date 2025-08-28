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
final class IncomeSource: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Double
    /// "weekly", "biweekly", "monthly"
    var frequency: String
    var startDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        frequency: String,
        startDate: Date
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency.lowercased()
        self.startDate = startDate
    }
}
