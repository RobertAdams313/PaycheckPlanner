//
//  PaycheckPlannerApp.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct PaycheckPlannerApp: App {
    // Store the router at the App level so tab selection survives re-renders.
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)   // <- survives theme changes
                .applyAppTheme()             // <- from your fixed AppTheme.swift
        }
        // Keep exactly ONE modelContainer in your app. If you already have one elsewhere,
        // delete this line to avoid duplicates.
        .modelContainer(for: [PaySchedule.self, IncomeSource.self, IncomeSchedule.self, Bill.self])
    }
}
