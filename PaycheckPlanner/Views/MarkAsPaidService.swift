//
//  MarkAsPaidService.swift
//  PaycheckPlanner
//
//  Toggle & query 'paid' flags per bill/occurrence using SwiftData.
//  Uses a normalized (startOfDay) `periodKey` so lookups are stable.
//  NOTE: We predicate on `periodKey` only and filter `bill` in-memory to avoid
//  macro/type-system issues comparing relationships inside #Predicate.
//

import Foundation
import SwiftData

enum MarkAsPaidService {

    @inline(__always)
    private static func key(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Return the BillPayment if one exists for this bill + periodKey.
    static func existingPayment(
        for bill: Bill,
        periodKey: Date,
        in context: ModelContext
    ) -> BillPayment? {
        let k = key(periodKey)

        // Predicate only on the date (stable, compiler-safe)
        let dateOnlyPredicate = #Predicate<BillPayment> { p in
            p.periodKey == k
        }
        let fd = FetchDescriptor<BillPayment>(predicate: dateOnlyPredicate)

        // Filter bill match in-memory (tiny set per day)
        return (try? context.fetch(fd))?
            .first { $0.bill.persistentModelID == bill.persistentModelID }
    }

    /// Fast “is paid?” check.
    static func isPaid(
        _ bill: Bill,
        periodKey: Date,
        in context: ModelContext
    ) -> Bool {
        existingPayment(for: bill, periodKey: periodKey, in: context) != nil
    }

    /// Flip state and return new value (`true` = now marked paid).
    @discardableResult
    @MainActor
    static func togglePaid(
        _ bill: Bill,
        periodKey: Date,
        in context: ModelContext
    ) -> Bool {
        if let existing = existingPayment(for: bill, periodKey: periodKey, in: context) {
            context.delete(existing)
            do { try context.save() } catch {
                context.insert(existing) // revert
                print("⚠️ MarkAsPaidService: delete save failed: \(error)")
            }
            return false
        } else {
            let stamp = BillPayment(bill: bill, periodKey: key(periodKey))
            context.insert(stamp)
            do {
                try context.save()
                return true
            } catch {
                context.delete(stamp)
                print("⚠️ MarkAsPaidService: insert save failed: \(error)")
                return false
            }
        }
    }
}
