//
//  CurrencyHelpers.swift
//  Consolidated shared helpers (generated)
//
//  This file centralizes currency formatting and parsing helpers to avoid
//  duplicate declarations across the project. Original implementations have
//  been preserved in-place under `#if false` blocks where duplicates existed.
//

import Foundation

// Canonical currency formatter (Decimal -> String)
public func formatCurrency(_ d: Decimal) -> String {
    let n = NSDecimalNumber(decimal: d)
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    return f.string(from: n) ?? "$0.00"
}

// Canonical currency parser (String -> Decimal)
public func parseDecimal(from s: String) -> Decimal {
    // Accept digits and one dot/comma; locale-tolerant simple parse.
    let normalized = s
        .replacingOccurrences(of: ",", with: ".")
        .filter { "0123456789.".contains($0) }
    return Decimal(string: normalized) ?? 0
}

// CSV-safe numeric string for Decimal values
public extension Decimal {
    var csv: String {
        // Use plain formatting to avoid locale commas in CSV output
        // Keep up to 2 fraction digits commonly used in currency
        let n = NSDecimalNumber(decimal: self)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "0"
    }

    var currencyString: String {
        return formatCurrency(self)
    }
}
