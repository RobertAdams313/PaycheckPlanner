//
//  CSVKit.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/3/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  CSVKit.swift
//  PaycheckPlanner
//
//  Centralized CSV helpers (string escaping and numeric formatting).
//
import Foundation

extension String {
    /// Quote + escape inner quotes if needed, per RFC 4180.
    var csvEscaped: String {
        if isEmpty { return "" }
        let needsQuoting = contains(",") || contains("\"") || contains("\n")
        if needsQuoting {
            let doubled = replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return self
    }
}

extension Decimal {
    /// Numeric CSV output without currency symbol; US-decimal dot regardless of locale.
    var csv: String {
        let ns = self as NSDecimalNumber
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: ns) ?? "0"
    }
}
