//
//  Bill.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation
import SwiftData

@Model
final class Bill: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Double
    var dueDate: Date
    /// "weekly", "biweekly", "monthly", "yearly", "one-time"
    var repeatFrequency: String
    /// Optional user category; if empty, we auto-tag by name for insights
    var category: String

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        dueDate: Date,
        repeatFrequency: String,
        category: String = ""
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.repeatFrequency = repeatFrequency.lowercased()
        self.category = category
    }
}
