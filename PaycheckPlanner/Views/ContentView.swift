
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  ContentView.swift
//  PaycheckPlanner
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.tab) {

            // PLAN
            NavigationStack { PlanView() }
                .tabItem { Label("Plan", systemImage: "calendar") }
                .tag(MainTab.plan)

            // BILLS
            NavigationStack { BillsListView() }
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
        // Make router available app-wide
        .environmentObject(router)

        // Present the global "Add Bill" sheet
        .sheet(isPresented: $router.showAddBillSheet) {
            NavigationStack {
                BillEditorView(existingBill: nil) { _ in }
                    .navigationTitle("New Bill")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }

        // Respect the user’s appearance setting everywhere
        .preferredColorScheme(AppAppearance.currentColorScheme)
    }
}
