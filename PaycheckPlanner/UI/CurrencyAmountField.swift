//
//  CurrencyAmountField.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/30/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  CurrencyAmountField.swift
//  PaycheckPlanner
//

import SwiftUI

struct CurrencyAmountField: View {
    @Binding var amount: Decimal

    @FocusState private var isFocused: Bool
    @State private var text: String = ""

    private let locale = Locale.current
    private let currencyCode = (Locale.current.currency?.identifier) ?? "USD"

    var body: some View {
        TextField("Amount", text: $text)
            .keyboardType(.decimalPad)
            .focused($isFocused)
            .onAppear {
                text = displayString(from: amount)
            }
            .onChange(of: amount) { _, newValue in
                // If user isn't actively editing, keep the field in display (formatted) mode
                if !isFocused {
                    text = displayString(from: newValue)
                }
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    // Entering edit mode: show plain numeric, clear if zero
                    if amount == 0 {
                        text = ""
                    } else {
                        text = editingString(from: amount)
                    }
                } else {
                    // Leaving edit mode: parse and commit to amount, then show formatted
                    let parsed = parseDecimal(from: text) ?? 0
                    amount = parsed
                    text = displayString(from: amount)
                }
            }
            .onChange(of: text) { _, newText in
                // Optional: live-parse for external listeners (not required)
                // Prevent weird characters; allow only digits and one decimal sep
                _ = newText
            }
            .toolbar {
                // Keyboard accessory "Done"
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isFocused = false }
                }
            }
    }

    // MARK: - Formatting / Parsing

    private func displayString(from value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = currencyCode
        nf.maximumFractionDigits = 2
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }

    private func editingString(from value: Decimal) -> String {
        // Plain numeric string respecting locale decimal separator, no symbol/grouping
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.usesGroupingSeparator = false
        nf.maximumFractionDigits = 2
        return nf.string(from: value as NSDecimalNumber) ?? ""
    }

    private func parseDecimal(from input: String) -> Decimal? {
        // Accept both localized and "plain" input; strip currency symbols and grouping
        let decSep = locale.decimalSeparator ?? "."
        _ = "0123456789\(decSep)"
        // Remove currency symbols & spaces
        var cleaned = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: Locale.current.currencySymbol ?? "$", with: "")
        // Replace any non-decimal separators with nothing; normalize to dot for parsing
        cleaned = cleaned.map { ch in
            if ch == Character(decSep) || "0123456789".contains(ch) { return ch }
            return Character("")
        }.reduce("") { $0 + String($1) }

        // Convert localized decimal separator to dot for NSDecimalNumber parsing
        if decSep != "." {
            cleaned = cleaned.replacingOccurrences(of: decSep, with: ".")
        }

        // Edge cases: empty or just separator => nil
        if cleaned.isEmpty || cleaned == "." { return nil }

        let ns = NSDecimalNumber(string: cleaned)
        if ns == .notANumber { return nil }
        return ns.decimalValue
    }
}
