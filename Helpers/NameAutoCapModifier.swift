//
//  NameAutoCapModifier.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// Ensures names auto-capitalize after spaces while typing.
/// Applies `.textInputAutocapitalization(.words)` and also normalizes text with `localizedCapitalized` on every change.
struct NameAutoCapModifier: ViewModifier {
    @Binding var text: String

    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.words)
            .onChange(of: text) { newValue, oldValue in
                // Normalize to localized title casing (capitalizes after spaces).
                let normalized = newValue.localizedCapitalized
                if normalized != newValue {
                    text = normalized
                }
            }
            .onAppear {
                text = text.localizedCapitalized
            }
    }
}

extension View {
    /// Makes a text field capitalize words as you type (especially after spaces).
    func nameAutoCap(text: Binding<String>) -> some View {
        modifier(NameAutoCapModifier(text: text))
    }
}
