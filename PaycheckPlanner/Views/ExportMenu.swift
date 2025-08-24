//
//  ExportMenu.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// A simple export menu that generates a CSV and shares it via the iOS share sheet.
struct ExportMenu: View {
    let schedule: PaySchedule
    let bills: [Bill]
    let incomeSources: [IncomeSource]

    var body: some View {
        Menu {
            ShareLink(item: CSVBuilder.makeCSV(schedule: schedule, bills: bills, incomeSources: incomeSources)) {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
        } label: {
            Label("Export", systemImage: "arrow.up.doc")
        }
        .accessibilityLabel("Export data")
    }
}

// MARK: - CSV Builder

private enum CSVBuilder {
    static func makeCSV(schedule: PaySchedule, bills: [Bill], incomeSources: [IncomeSource]) -> URL {
        var rows: [String] = []

        // Header
        rows.append([
            "Section",
            "Name",
            "Amount",
            "Recurrence",
            "RecurrenceEnd",
            "Date",
            "Extra"
        ].joined(separator: ","))

        // Schedule summary
        let totalIncomePerPaycheck = incomeSources.reduce(Decimal(0)) { $0 + $1.defaultAmount }
        rows.append([
            "Schedule",
            escape(schedule.frequency.displayName),
            escape(totalIncomePerPaycheck.currencyString),
            "",                  // Recurrence
            "",                  // RecurrenceEnd
            iso(schedule.anchorDate),
            "Anchor payday"
        ].joined(separator: ","))

        // Income sources
        for inc in incomeSources {
            rows.append([
                "Income",
                escape(inc.name),
                escape(inc.defaultAmount.currencyString),
                "",      // Recurrence
                "",      // RecurrenceEnd
                "",      // Date
                ""       // Extra / Notes (not present in model)
            ].joined(separator: ","))
        }

        // Bills
        for b in bills {
            rows.append([
                "Bill",
                escape(b.name),
                escape(b.amount.currencyString),
                escape(b.recurrence.displayName),
                "", // RecurrenceEnd (not in current model; leave blank)
                iso(b.anchorDueDate),
                "First due date"
            ].joined(separator: ","))
        }

        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaycheckPlanner_Export_\(Int(Date().timeIntervalSince1970)).csv")

        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        } catch {
            // Best-effort: if writing fails, try a different filename
            let fallback = FileManager.default.temporaryDirectory
                .appendingPathComponent("PaycheckPlanner_Export.csv")
            try? csv.data(using: .utf8)?.write(to: fallback, options: .atomic)
            return fallback
        }

        return url
    }

    // MARK: helpers

    private static func escape(_ s: String) -> String {
        // CSV-safe: wrap with quotes if needed and escape inner quotes
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        } else {
            return s
        }
    }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }
}
