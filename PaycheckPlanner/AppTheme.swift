
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  AppTheme.swift
//  PaycheckPlanner
//

import SwiftUI

enum AppAppearance {
    /// Reads the user’s stored appearance preference and maps to SwiftUI ColorScheme.
    static var currentColorScheme: ColorScheme? {
        // Match the key your Settings uses. Defaults to "system".
        let choice = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        switch choice.lowercased() {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // system
        }
    }
}
