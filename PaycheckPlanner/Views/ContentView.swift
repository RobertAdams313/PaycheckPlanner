//
//  ContentView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/1/25
//  Copyright © 2025 Rob Adams. All rights reserved.
//

// Inside ContentView.swift

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var router = AppRouter()
    @State private var didApplyDefaultTab = false

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
        .onAppear {
            guard !didApplyDefaultTab else { return }
            didApplyDefaultTab = true
            switch AppPreferences.defaultTabRaw {
            case "bills": router.tab = .bills
            case "income": router.tab = .income
            case "insights": router.tab = .insights
            case "settings": router.tab = .settings
            default: router.tab = .plan
            }
        }
    }
}
