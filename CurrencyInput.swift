//
//  CurrencyInput.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import Foundation

// MARK: - Currency Formatting Utilities

enum CurrencyInput {
    static func formatted(from raw: String, currencyCode: String? = nil, locale: Locale = .current) -> String {
        // Keep digits only, interpret as cents
        let digits = raw.filter(\.isNumber)
        guard let cents = Double(digits) else { return "" }
        let value = cents / 100.0
        return formatCurrency(value, currencyCode: currencyCode, locale: locale)
    }

    static func parseDouble(_ formatted: String, locale: Locale = .current) -> Double {
        // Remove all except digits, decimal separator, and minus
        let allowed = CharacterSet(charactersIn: "0123456789\(locale.decimalSeparator ?? ".")-")
        let cleaned = String(formatted.unicodeScalars.filter { allowed.contains($0) })
        // Fallback to cents logic if decimal parsing fails
        if let n = NumberFormatter.localizedDecimal(locale: locale).number(from: cleaned) {
            return n.doubleValue
        } else {
            let digits = formatted.filter(\.isNumber)
            let cents = Double(digits) ?? 0
            return cents / 100.0
        }
    }

    static func formatCurrency(_ value: Double, currencyCode: String? = nil, locale: Locale = .current) -> String {
        let nf = NumberFormatter.currency(locale: locale, code: currencyCode)
        return nf.string(from: NSNumber(value: value)) ?? ""
    }
}

private extension NumberFormatter {
    static func currency(locale: Locale, code: String?) -> NumberFormatter {
        let nf = NumberFormatter()
        nf.locale = locale
        nf.numberStyle = .currency
        if let code { nf.currencyCode = code }
        return nf
    }

    static func localizedDecimal(locale: Locale) -> NumberFormatter {
        let nf = NumberFormatter()
        nf.locale = locale
        nf.numberStyle = .decimal
        nf.generatesDecimalNumbers = false
        return nf
    }
}

// MARK: - View Modifier

struct CurrencyInputModifier: ViewModifier {
    @Binding var text: String
    var currencyCode: String?
    var locale: Locale = .current

    func body(content: Content) -> some View {
        content
            .keyboardType(.numberPad) // Dial pad for currency entry
            .onChange(of: text) { newValue in
                // Reformat continuously as currency
                text = CurrencyInput.formatted(from: newValue, currencyCode: currencyCode, locale: locale)
            }
            .onAppear {
                if text.isEmpty {
                    text = CurrencyInput.formatted(from: "0", currencyCode: currencyCode, locale: locale)
                } else {
                    text = CurrencyInput.formatted(from: text, currencyCode: currencyCode, locale: locale)
                }
            }
    }
}

extension View {
    /// Formats a bound String as currency while the user types (digits = cents).
    func currencyInput(text: Binding<String>, currencyCode: String? = nil, locale: Locale = .current) -> some View {
        modifier(CurrencyInputModifier(text: text, currencyCode: currencyCode, locale: locale))
    }
}
