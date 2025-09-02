//
//  ContentView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var router = AppRouter()
    @State private var didApplyDefaultTab = false

    // Read the same key your Settings picker writes: "system" | "light" | "dark"
    @AppStorage("appearance") private var appearance: String = "system"

    /// Convert stored appearance to an optional ColorScheme.
    /// Returning nil allows the app to follow the system appearance.
    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil // "system"
        }
    }

    var body: some View {
        TabView(selection: $router.tab) {
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(MainTab.plan)

            NavigationStack { BillsView() }
                .tabItem { Label("Bills", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.bills)

            NavigationStack { IncomeSourcesView() }
                .tabItem { Label("Income", systemImage: "banknote") }
                .tag(MainTab.income)

            NavigationStack { InsightsHostView() }
                .tabItem { Label("Insights", systemImage: "chart.pie") }
                .tag(MainTab.insights)

            NavigationStack { SettingsHostView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .environmentObject(router)

        // 🔔 Add notification scheduling + deep-link handlers at the root:
        .withNotificationsBootstrap()    // keeps notifications up to date
        .withNotificationDeepLinking()   // optional: present PaycheckDetail from a tap event

        // Apply the appearance override at the top-most level so it affects the entire app.
        .preferredColorScheme(preferredScheme)
        .onAppear {
            guard !didApplyDefaultTab else { return }
            didApplyDefaultTab = true
            switch AppPreferences.defaultTabRaw {
            case "bills":    router.tab = .bills
            case "income":   router.tab = .income
            case "insights": router.tab = .insights
            case "settings": router.tab = .settings
            default:         router.tab = .plan
            }
        }
    }
}
