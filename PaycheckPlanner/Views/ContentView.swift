//
//  ContentView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// Main tab container. Uses the App-level router so selection persists.
struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.tab) {
            // PLAN
            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(MainTab.plan)

            // BILLS
            BillsListView()
                .tabItem { Label("Bills", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.bills)

            // INCOME
            IncomeSourcesView()
                .tabItem { Label("Income", systemImage: "banknote") }
                .tag(MainTab.income)

            // INSIGHTS
            InsightsHostView()
                .tabItem { Label("Insights", systemImage: "chart.pie") }
                .tag(MainTab.insights)

            // SETTINGS
            SettingsHostView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
    }
}
