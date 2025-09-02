//
//  AppBootstrapView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  AppBootstrapView.swift
//  PaycheckPlanner
//

import SwiftUI
import SwiftData

/// Ensures there's a starter PaySchedule and heals legacy IncomeSchedule links,
/// then shows the main UI.
struct AppBootstrapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PaySchedule.anchorDate, order: .forward) private var schedules: [PaySchedule]

    var body: some View {
        ContentView()
            .task {
                // 1) Seed one PaySchedule so Plan/Insights have a reference frame.
                if schedules.isEmpty {
                    let schedule = PaySchedule(frequency: .biweekly, anchorDate: .now)
                    context.insert(schedule)
                    try? context.save()
                }

                // 2) Backfill: make sure every IncomeSchedule points at its owner source.
                await backfillIncomeScheduleOwners()
            }
    }

    @MainActor
    private func backfillIncomeScheduleOwners() async {
        do {
            let sources = try context.fetch(FetchDescriptor<IncomeSource>())
            var changed = false
            for src in sources {
                if let sch = src.schedule, sch.source == nil {
                    sch.source = src
                    changed = true
                }
            }
            if changed { try context.save() }
        } catch {
            // Non-fatal on startup
        }
    }
}
