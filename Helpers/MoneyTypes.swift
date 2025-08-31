//
//  public.swift
//  Paycheck Planner
//
//  Created by Rob on 8/28/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  MoneyTypes.swift
//  Paycheck Planner
//
//  A tiny unifying layer so views work whether models use Decimal or Double.
//  Keep Decimal in the data layer for correctness; Double only for UI/Charts.
//

import Foundation

// MARK: - Unifying protocol

public protocol MoneyConvertible {
    /// Lossless representation for storage/arithmetic.
    var asDecimal: Decimal { get }
    /// Bridge for UI/Charts/animations that require Double.
    var asDouble: Double { get }
}

// MARK: - Decimal

extension Decimal: MoneyConvertible {
    public var asDecimal: Decimal { self }
    public var asDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}

// MARK: - Double

extension Double: MoneyConvertible {
    public var asDecimal: Decimal { Decimal(self) }
    public var asDouble: Double { self }
}

// MARK: - Convenience formatters

extension MoneyConvertible {
    /// Currency string using the current locale (safe for both Decimal/Double).
    func currencyString(code: String? = Locale.current.currency?.identifier) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code ?? "USD"
        // Use Decimal backing to avoid FP noise when possible
        if let number = asDecimal as NSDecimalNumber? {
            return formatter.string(from: number) ?? "\(asDouble)"
        }
        return formatter.string(from: NSNumber(value: asDouble)) ?? "\(asDouble)"
    }
}
