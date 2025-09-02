//
//  MoneyRounding.swift
//  PaycheckPlanner
//
//  Display-only rounding helper that respects AppPreferences.roundingPref.
//  Use in Views: total.ppRoundedForDisplay().formatted(.currency(code: ...))
//

import Foundation

extension Decimal {
    func ppRoundedForDisplay() -> Decimal {
        // "exact" | "nearestDollar" (default "exact")
        let pref = AppPreferences.roundingPref
        guard pref == "nearestDollar" else { return self }

        var x = self
        var y = Decimal()
        NSDecimalRound(&y, &x, 0, .bankers)
        return y
    }
}
