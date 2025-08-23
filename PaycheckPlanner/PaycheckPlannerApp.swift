//
//  PaycheckPlannerApp.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  PaycheckPlannerApp.swift
//  PaycheckPlanner
//

import SwiftUI
import SwiftData

@main
struct PaycheckPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView() // owns AppRouter & TabView
        }
        .modelContainer(for: [
            IncomeSource.self,
            IncomeSchedule.self,
            Bill.self,
            PaySchedule.self
        ])
    }
}
