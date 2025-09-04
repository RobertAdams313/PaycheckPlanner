//
//  CurrencyFormat.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/3/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  CurrencyKit.swift
//  PaycheckPlanner
//
//  Centralized currency formatting & parsing.
//  Use Decimal.currencyString for display; CurrencyParser.parse(_) for user input.
//
import Foundation

enum CurrencyFormat {
    static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.generatesDecimalNumbers = true
        f.locale = .current
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()
}

extension Decimal {
    /// Locale-aware currency string for UI display.
    var currencyString: String {
        CurrencyFormat.formatter.string(from: self as NSDecimalNumber) ?? "$0.00"
    }
}

enum CurrencyParser {
    /// Robust, locale-tolerant parse. Accepts "1,234.56" or "1234,56" etc.
    static func parse(_ raw: String) -> Decimal {
        // Try strict locale parse first.
        if let number = CurrencyFormat.formatter.number(from: raw) {
            return number.decimalValue
        }
        // Fallback: keep digits and at most one decimal separator.
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        let allowed = "0123456789" + decimalSeparator
        var cleaned = raw.filter { allowed.contains($0) }

        // Normalize dot/comma to locale
        if decimalSeparator == "," {
            cleaned = cleaned.replacingOccurrences(of: ".", with: ",")
        } else {
            cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        }
        // Keep only first decimal separator
        if let idx = cleaned.firstIndex(of: Character(decimalSeparator)) {
            let after = cleaned.index(after: idx)
            var head = String(cleaned[..<after])
            let tail = String(cleaned[after...]).replacingOccurrences(of: String(decimalSeparator), with: "")
            cleaned = head + tail
        }
        return Decimal(string: cleaned) ?? 0
    }
}
