//
//  AppTheme.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


// AppTheme.swift  — drop-in replacement
import SwiftUI

/// Matches your @AppStorage("themeMode") Int (0=system, 1=light, 2=dark)
enum AppTheme: Int, CaseIterable, Identifiable {
    case system = 0
    case light  = 1
    case dark   = 2
    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    // Convenience for binding to @AppStorage("themeMode")
    static let storageKey = "themeMode"

    static func binding() -> Binding<AppTheme> {
        Binding<AppTheme>(
            get: {
                let raw = UserDefaults.standard.integer(forKey: storageKey)
                return AppTheme(rawValue: raw) ?? .system
            },
            set: { newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
            }
        )
    }
}

/// Applies the theme from @AppStorage("themeMode") to the entire subtree.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppTheme.storageKey) private var modeRaw: Int = AppTheme.system.rawValue
    private var scheme: ColorScheme? { AppTheme(rawValue: modeRaw)?.colorScheme }

    func body(content: Content) -> some View {
        content.preferredColorScheme(scheme)
    }
}

extension View {
    /// Call once at the app root (WindowGroup/ContentView).
    func applyAppTheme() -> some View {
        modifier(AppThemeModifier())
    }
}
