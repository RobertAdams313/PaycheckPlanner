//
//  NameAutoCapModifier.swift
//  PaycheckPlanner
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
            .onChange(of: text) { newValue in
                let normalized = newValue.localizedCapitalized
                if normalized != newValue {
                    text = normalized
                }
            }
    }
}

extension View {
    func nameAutoCap(_ text: Binding<String>) -> some View {
        self.modifier(NameAutoCapModifier(text: text))
    }
}
