//
//  AppBootstrapView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct AppBootstrapView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    var body: some View {
        TabView {
            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }

            IncomeSourcesView()
                .tabItem { Label("Income", systemImage: "dollarsign.circle") }

            BillsView()
                .tabItem { Label("Bills", systemImage: "list.bullet") }

            InsightsHostView()
                .tabItem { Label("Insights", systemImage: "chart.pie") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme((AppTheme(rawValue: appThemeRaw) ?? .system).colorSchemeOverride)
    }
}
