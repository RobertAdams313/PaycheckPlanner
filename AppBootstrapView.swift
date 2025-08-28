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
    var body: some View {
        TabView {
            PlanView()
                .tabItem { Label("Plan", systemImage: "calendar") }

            IncomeSourcesView()
                .tabItem { Label("Income", systemImage: "dollarsign.circle") }

            BillsView()
                .tabItem { Label("Bills", systemImage: "list.bullet") }
        }
    }
}
