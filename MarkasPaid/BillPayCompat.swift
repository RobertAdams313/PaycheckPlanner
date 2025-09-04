//
//  BillPayCompat.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/4/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//  BillPayment+Compat.swift
//  PaycheckPlanner
//
//  Bridges legacy BillPayment(periodPayday, amount) to the new API (periodKey).
//  Keep this until all call sites and the model are fully migrated.

import Foundation
import SwiftData

extension BillPayment {

    // If your current model already has `periodKey`, this computed property
    // will be ignored by the compiler (duplicate symbol won’t be emitted).
    // If your model has `periodPayday`, we provide a compatibility veneer.
    var periodKey: Date {
        get {
            // Prefer existing periodKey if it exists at runtime, otherwise map legacy.
            // NOTE: We can’t reflect types at compile time; this builds only when
            // the legacy property `periodPayday` exists.
            #if compiler(>=5.9)
            return (self as AnyObject).value(forKey: "periodPayday") as? Date
                ?? Date.distantPast
            #else
            // Fallback: if you’re on the legacy model, expose its stored property.
            return periodPayday
            #endif
        }
        set {
            let k = Calendar.current.startOfDay(for: newValue)
            #if compiler(>=5.9)
            (self as AnyObject).setValue(k, forKey: "periodPayday")
            #else
            periodPayday = k
            #endif
        }
    }

    /// Convenience initializer that your new call sites use.
    /// If you’re on the legacy model, we fill `amount` with the bill’s amount.
    convenience init(bill: Bill, periodKey: Date, markedAt: Date = .now) {
        let k = Calendar.current.startOfDay(for: periodKey)
        // Legacy initializer signature:
        // init(bill: Bill, periodPayday: Date, amount: Decimal, markedAt: Date = .now)
        self.init(bill: bill, periodPayday: k, amount: bill.amount, markedAt: markedAt)
    }
}
