//
//  CurrencyCentsField.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// Currency input that only shows the formatted dollar amount.
/// Typing uses a digits-only buffer that "grows cents":
/// 0.00 -> type 5 -> 0.05 -> type 5 -> 0.55 -> type 1 -> 5.51, etc.
struct CurrencyCentsField: View {
    @Binding var amount: Decimal
    var label: String = "Amount"

    @State private var digits: String = ""    // raw cents buffer (e.g. "551" -> $5.51)
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent(label) {
            ZStack(alignment: .leading) {
                // Visible, formatted amount only
                Text(amount.currencyString)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)

                // Invisible TextField to capture typing (number pad)
                TextField("", text: $digits)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
                    .opacity(0.02)         // keep interactive but invisible
                    .tint(.clear)          // hide caret color
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: digits) { oldVal, newVal in  // iOS 17+ two-parameter onChange
                        // Keep only digits, cap length
                        let clean = newVal.filter(\.isNumber).prefix(12)
                        if clean != newVal { digits = String(clean) }

                        // Update bound decimal (cents -> dollars)
                        let cents = Decimal(Int(clean) ?? 0)
                        amount = cents / 100
                    }
                    .onAppear {
                        // Seed the buffer from any pre-set amount
                        let cents = NSDecimalNumber(decimal: amount).multiplying(by: 100).intValue
                        digits = String(max(0, cents))
                    }
            }
            // Tap anywhere on the row to focus the (hidden) field
            .contentShape(Rectangle())
            .onTapGesture { isFocused = true }
            // Accessibility still reads like a text field with the currency value
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(amount.currencyString))
        }
    }
}
