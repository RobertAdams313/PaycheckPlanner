//
//  Income.swift
//  PaycheckPlanner
//

import Foundation

/// Lightweight value used by the projection engines (not a SwiftData @Model).
struct Income: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var name: String
    var amount: Decimal
    var frequency: IncomeFrequency
    var startDate: Date
    /// For `.oneTime`, if set this exact date is used; else `startDate`.
    var oneTimeDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        frequency: IncomeFrequency,
        startDate: Date,
        oneTimeDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.startDate = startDate
        self.oneTimeDate = oneTimeDate
    }
}
