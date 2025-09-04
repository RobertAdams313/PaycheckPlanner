//
//  NameAutoCapModifier.swift
//  PaycheckPlanner
//
//  Updated for iOS 17 onChange API, with iOS 16 fallback.
//  Preserves ALL CAPS user intent and special-case words.
//

import SwiftUI

/// ViewModifier that auto-capitalizes names while:
/// - Allowing ALL CAPS if the user is deliberately typing in caps
/// - Preserving the last typed word if it matches a special-case (e.g., "iCloud")
struct NameAutoCapModifier: ViewModifier {
    @Binding var text: String

    /// Add your popular/special brand/style cases here ("iCloud", "iPad", etc.)
    private let specialCases: Set<String> = [
        "iCloud", "iPad", "iPhone", "iMac", "macOS", "tvOS", "watchOS"
    ]

    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.words)
            // iOS 17+ two-parameter closure (preferred)
            .modifier(OnChangeCompat(text: $text) { oldValue, newValue in
                guard !newValue.isEmpty else { return }

                // Allow ALL CAPS (user intent)
                if newValue == newValue.uppercased() {
                    return
                }

                // If last typed word is in special cases, preserve it
                let words = newValue.split(separator: " ").map(String.init)
                if let last = words.last, specialCases.contains(last) {
                    return
                }

                // Otherwise auto-capitalize normally
                let normalized = newValue.localizedCapitalized
                if normalized != newValue {
                    text = normalized
                }
            })
    }
}

// MARK: - iOS 17 onChange compatibility shim

/// Wraps `.onChange` using the iOS 17 two-parameter closure when available,
/// and falls back to the single-parameter version on earlier iOS.
private struct OnChangeCompat: ViewModifier {
    @Binding var text: String
    let action: (_ oldValue: String, _ newValue: String) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: text) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            content.onChange(of: text) { newValue in
                action(text, newValue)
            }
        }
    }
}

// MARK: - Convenience

extension View {
    /// Apply automatic name capitalization rules to a bound String.
    func nameAutoCap(_ text: Binding<String>) -> some View {
        modifier(NameAutoCapModifier(text: text))
    }
}
