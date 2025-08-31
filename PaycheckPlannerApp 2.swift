//
//  PaycheckPlannerApp 2.swift
//  Paycheck Planner
//
//  Created by Rob on 8/28/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

@main
struct PaycheckPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
        }
        // SwiftData models your app uses. Add others here if needed.
        .modelContainer(for: [
            Bill.self,
            IncomeSource.self
        ])
    }
}
