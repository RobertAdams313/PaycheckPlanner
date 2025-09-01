//
//  AppBootstrapView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Ensures there's a starter PaySchedule, then shows the real root UI.
struct AppBootstrapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PaySchedule.anchorDate, order: .forward) private var schedules: [PaySchedule]

    var body: some View {
        ContentView()
            .task {
                // Seed a default schedule on first run so the UI has data to render.
                if schedules.isEmpty {
                    let schedule = PaySchedule(frequency: .biweekly, anchorDate: .now)
                    context.insert(schedule)
                    try? context.save()
                }
            }
    }
}
