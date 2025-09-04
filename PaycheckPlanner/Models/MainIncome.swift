//
//  MainIncome.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/3/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  MainIncome.swift
//  PaycheckPlanner
//
//  Small helper to ensure only one schedule is marked as main at a time.
//
import Foundation
import SwiftData

enum MainIncome {
    @MainActor
    static func setMain(_ schedule: IncomeSchedule, in context: ModelContext) {
        if let all: [IncomeSchedule] = try? context.fetch(FetchDescriptor<IncomeSchedule>()) {
            for s in all { s.isMain = (s == schedule) }
        } else {
            schedule.isMain = true
        }
        try? context.save()
    }

    @MainActor
    static func clearMain(in context: ModelContext) {
        if let all: [IncomeSchedule] = try? context.fetch(FetchDescriptor<IncomeSchedule>()) {
            for s in all { s.isMain = false }
            try? context.save()
        }
    }

    @MainActor
    static func currentMain(in context: ModelContext) -> IncomeSchedule? {
        (try? context.fetch(FetchDescriptor<IncomeSchedule>()))?.first(where: { $0.isMain })
    }
}
