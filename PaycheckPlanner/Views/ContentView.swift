//
//  ContentView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/1/25
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var router = AppRouter()

    // Read the same key your Settings picker writes: "system" | "light" | "dark"
    @AppStorage("appearance") private var appearance: String = "system"

    /// Map the string to an optional ColorScheme.
    /// Returning nil tells SwiftUI to follow the system setting.
    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil // "system"
        }
    }

    var body: some View {
        TabView(selection: $router.tab) {
            // PLAN
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(MainTab.plan)

            // BILLS
            NavigationStack { BillsView() }
                .tabItem { Label("Bills", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.bills)

            // INCOME
            NavigationStack { IncomeSourcesView() }
                .tabItem { Label("Income", systemImage: "banknote") }
                .tag(MainTab.income)

            // INSIGHTS
            NavigationStack { InsightsHostView() }
                .tabItem { Label("Insights", systemImage: "chart.pie") }
                .tag(MainTab.insights)

            // SETTINGS
            NavigationStack { SettingsHostView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .environmentObject(router)
        // Apply at the top-most level so all screens react instantly.
        .preferredColorScheme(preferredScheme)
    }
}
