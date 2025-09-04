//
//  BillPaidHelpers.swift
//  PaycheckPlanner
//
//  Engine-safe helpers for “Mark as Paid” wiring.
//  Uses CombinedPayEventsEngine.combinedPeriods -> [CombinedPeriod].
//  No reliance on period.items; for amounts we fall back to Bill.amount.
//

import Foundation

/// Returns the first (current) CombinedPeriod, if available.
func currentCombinedPeriod(schedules: [IncomeSchedule]) -> CombinedPeriod? {
    CombinedPayEventsEngine
        .combinedPeriods(schedules: schedules, count: 1)
        .first
}

/// Convenience to read the payday key used for paid-state.
func periodPayday(from period: CombinedPeriod?) -> Date? {
    period?.payday
}

/// Returns the amount to record when marking a bill paid for the given period.
/// Since your CombinedPeriod doesn’t expose per-period line items, we use the bill’s base amount.
/// If later you add period items, swap this to return that period’s allocated total.
func lineTotal(for bill: Bill, in period: CombinedPeriod?) -> Decimal {
    bill.amount
}

// ----------------------------------------------------------------------
// Optional shims (keep callers compiling if older code used these names)
// ----------------------------------------------------------------------

@available(*, deprecated, message: "Use currentCombinedPeriod(schedules:) instead.")
func currentCombinedBreakdown(schedules: [IncomeSchedule]) -> CombinedPeriod? {
    currentCombinedPeriod(schedules: schedules)
}
