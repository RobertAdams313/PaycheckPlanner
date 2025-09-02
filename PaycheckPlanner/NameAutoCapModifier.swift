//
//  NameAutoCapModifier.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/27/25.
//  Updated on 9/2/25 – Added overrides for ALL CAPS and popular special-case names.
//

import SwiftUI

/// Ensures names auto-capitalize after spaces while typing.
/// - Normalizes text with `localizedCapitalized`
/// - Preserves ALL CAPS if the user typed it that way
/// - Preserves special brand/product names (like "iCloud", "eBay")
struct NameAutoCapModifier: ViewModifier {
    @Binding var text: String

    /// Popular brand/product names that should keep their casing.
    private let specialCases: [String] = [
        "iCloud", "iPhone", "iPad", "iOS", "iMac",
        "MacBook", "AirPods", "Apple Watch",
        "YouTube", "Gmail", "Google Drive", "Google Maps",
        "PayPal", "Venmo", "Zelle", "Cash App",
        "eBay", "iTunes", "FaceTime", "Zoom",
        "Spotify", "Netflix", "Disney+", "Hulu",
        "WhatsApp", "Messenger", "Instagram", "TikTok",
        "X", "LinkedIn", "Snapchat", "Reddit"
    ]

    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.words)
            .onChange(of: text) { newValue in
                guard !newValue.isEmpty else { return }

                // Allow ALL CAPS (user intent)
                if newValue == newValue.uppercased() {
                    return
                }

                // If last typed word is in special cases, preserve it
                let words = newValue.split(separator: " ").map(String.init)
                if let last = words.last,
                   specialCases.contains(last) {
                    return
                }

                // Otherwise auto-capitalize normally
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
