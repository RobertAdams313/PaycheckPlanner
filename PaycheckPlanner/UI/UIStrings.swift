//
//  UIStrings.swift
//  PaycheckPlanner
//

import Foundation

// MARK: - Friendly display names (non-breaking UI layer)
extension PayFrequency {
    var uiName: String {
        switch self {
        case .once:        return "One time"
        case .weekly:      return "Weekly"
        case .biweekly:    return "Biweekly"
        case .semimonthly: return "Semi-monthly"
        case .monthly:     return "Monthly"
        }
    }
}

extension BillRecurrence {
    var uiName: String {
        switch self {
        case .once:         return "One time"
        case .weekly:       return "Weekly"
        case .biweekly:     return "Biweekly"          // <- wording update
        case .semimonthly:  return "Semi-monthly"
        case .monthly:      return "Monthly"
        }
    }
    
    /// For the Bill editor UI we don’t want to offer Semi-monthly (per your request),
    /// but we keep it in the data model for backward compatibility.
    static var allCasesForBillEditor: [BillRecurrence] {
        BillRecurrence.allCases.filter { $0 != .semimonthly }
    }
}

// MARK: - Small date helpers
func uiDateIntervalString(_ start: Date, _ end: Date) -> String {
    let style = Date.IntervalFormatStyle(date: .abbreviated, time: .omitted)
    // If end < start, swap to avoid a crashy interval
    let (lo, hi) = start <= end ? (start, end) : (end, start)
    return style.format(lo..<hi)
}


func uiMonthDay(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
}

// Back-compat for older call sites (e.g. ExportMenu.swift)
extension PayFrequency {
    var displayName: String { uiName }
}

extension BillRecurrence {
    var displayName: String { uiName }
}
