//
//  BillPayment.swift
//  PaycheckPlanner
//
//  Tracks a Bill paid state for a specific occurrence (keyed by that bill's
//  period day; we normalize to startOfDay to avoid time drift).
//

import Foundation
import SwiftData

@Model
final class BillPayment {
    @Relationship var bill: Bill
    /// Start-of-day key for the *period* containing this bill occurrence.
    var periodKey: Date
    /// Timestamp when the user marked it paid (UI/insights only).
    var markedAt: Date

    init(bill: Bill, periodKey: Date, markedAt: Date = .now) {
        self.bill = bill
        self.periodKey = Calendar.current.startOfDay(for: periodKey)
        self.markedAt = markedAt
    }
}
