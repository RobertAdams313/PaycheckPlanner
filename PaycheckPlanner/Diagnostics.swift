//
//  Diagnostics.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import os.log

enum Diagnostics {
    private static let log = Logger(subsystem: "PaycheckPlanner", category: "Diagnostics")

    static func run(schedules: [PaySchedule], bills: [Bill], incomes: [IncomeSource]) -> [String] {
        var issues: [String] = []

        if schedules.isEmpty { issues.append("No PaySchedule found (SetupView should create one).") }
        if bills.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            issues.append("One or more bills have empty names.")
        }
        if incomes.contains(where: { $0.defaultAmount < 0 }) {
            issues.append("Income source with negative amount.")
        }

        // Semimonthly day sanity
        if let s = schedules.first, s.frequency == .semimonthly {
            if !(1...28).contains(s.semimonthlyFirstDay) || !(1...28).contains(s.semimonthlySecondDay) {
                issues.append("Semi-monthly days must be between 1 and 28.")
            }
        }

        if issues.isEmpty { issues.append("No issues detected.") }
        for i in issues { log.info("Diagnostic: \(i, privacy: .public)") }
        return issues
    }
}
