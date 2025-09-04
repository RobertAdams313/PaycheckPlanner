//
//  DataResetService.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  DataResetService.swift
//  PaycheckPlanner
//
//  Provides a single, safe entrypoint to wipe all app data.
//

import Foundation
import SwiftData

enum DataResetService {

    /// Wipes all SwiftData objects and clears relevant UserDefaults keys.
    /// Call from the main actor (e.g., inside a Button action).
    @MainActor
    static func wipeAll(context: ModelContext) throws {
        try context.transaction {
            // Delete Bills first (no dependents)
            let bills = try context.fetch(FetchDescriptor<Bill>())
            bills.forEach { context.delete($0) }

            // Delete Schedules next (their `source` is cascade-linked in your model)
            let schedules = try context.fetch(FetchDescriptor<IncomeSchedule>())
            schedules.forEach { context.delete($0) }

            // Clean up any orphaned IncomeSource (in case some aren’t linked)
            let sources = try context.fetch(FetchDescriptor<IncomeSource>())
            sources.forEach { context.delete($0) }

            try context.save()
        }

        // Clear preferences used by your engines/UI
        let ud = UserDefaults.standard
        ud.removeObject(forKey: "planPeriodCount")
        ud.removeObject(forKey: "carryoverEnabled")
    }
}
