//
//  BillPayment.swift
//  PaycheckPlanner
//
//  Records a paid occurrence for a Bill keyed by a Date (periodKey).
//

import Foundation
import SwiftData

@Model
final class BillPayment {
    @Relationship(deleteRule: .nullify)
    var bill: Bill?

    /// Key date representing the occurrence (we’re using startOfDay(anchorDueDate) for BillsView).
    var periodKey: Date

    var createdAt: Date

    init(bill: Bill, periodKey: Date) {
        self.bill = bill
        self.periodKey = Calendar.current.startOfDay(for: periodKey)
        self.createdAt = Date()
    }
}
