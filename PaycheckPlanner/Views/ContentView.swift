
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


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

            // Income tab -> use the drop-in IncomeSourcesView below (adds + and editor)
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

        // Global “Add Bill” sheet — BillEditorView(bill:) expects a non-optional Bill
        .sheet(isPresented: $router.showAddBillSheet) {
            NavigationStack {
                BillEditorView(bill: Bill())
                    .navigationTitle("New Bill")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }

        // Respect the user’s appearance setting everywhere
        .preferredColorScheme(AppAppearance.currentColorScheme)
    }
}

