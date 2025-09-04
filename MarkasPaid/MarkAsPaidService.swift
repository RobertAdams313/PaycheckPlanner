//  MarkAsPaidService.swift
//  PaycheckPlanner
//
//  Optional-safe SwiftData helpers to toggle/query a bill's paid state for a given occurrence.
//  We filter by periodKey in the predicate (no optional relationship in the predicate),
//  then match the Bill by persistentModelID in memory to avoid macro/optional issues.
//

import Foundation
import SwiftData

@MainActor
enum MarkAsPaidService {

    @inline(__always)
    private static func key(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Returns the BillPayment if one exists for (bill, periodKey)
    private static func existing(_ bill: Bill, on date: Date, in context: ModelContext) -> BillPayment? {
        let pk = key(date)
        let targetID = bill.persistentModelID

        // Predicate ONLY on the scalar periodKey to avoid optional relationship comparisons.
        let fetch = FetchDescriptor<BillPayment>(
            predicate: #Predicate<BillPayment> { payment in
                payment.periodKey == pk
            }
        )

        guard let matches = try? context.fetch(fetch) else { return nil }
        return matches.first { $0.bill?.persistentModelID == targetID }
    }

    /// True if the bill is marked paid for this occurrence.
    static func isPaid(_ bill: Bill, on date: Date, in context: ModelContext) -> Bool {
        existing(bill, on: date, in: context) != nil
    }

    /// Toggle paid/unpaid. Returns the new state (true = now paid).
    @discardableResult
    static func togglePaid(_ bill: Bill, on date: Date, in context: ModelContext) -> Bool {
        if let current = existing(bill, on: date, in: context) {
            context.delete(current)
            try? context.save()
            return false
        } else {
            let payment = BillPayment(bill: bill, periodKey: key(date))
            context.insert(payment)
            try? context.save()
            return true
        }
    }
}
