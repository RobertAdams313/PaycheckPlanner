//
//  DataCSVExporter.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/2/25.
//  Purpose: Export SwiftData domain models (Bills, Income Sources/Schedules) to a single CSV,
//           using concrete SwiftData types (no existentials) so it compiles reliably.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

enum DataCSVExporter {
    struct ExportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Export all Bills and Income Sources (+Schedules) into one CSV written to a temp file.
    /// Columns: Type,Name,Amount,Date,RecurrenceOrFrequency,Category
    static func exportAllDataCSV(context: ModelContext) throws -> URL {
        // Fetch concrete SwiftData types (no 'any PersistentModel' existentials)
        let bills: [Bill] = try context.fetch(FetchDescriptor<Bill>())
        let sources: [IncomeSource] = try context.fetch(FetchDescriptor<IncomeSource>())

        var rows: [String] = []
        rows.reserveCapacity((bills.count + sources.count) + 1)
        rows.append("Type,Name,Amount,Date,RecurrenceOrFrequency,Category")

        // Bills
        for b in bills {
            let type = "Bill"
            let name = b.name
            let amount = formatDecimal(b.amount)
            let dateStr = formatDate(b.anchorDueDate)
            let recurrence = b.recurrence.rawValue
            let category = b.category.isEmpty ? "Uncategorized" : b.category

            rows.append([
                type.csv, name.csv, amount.csv, dateStr.csv, recurrence.csv, category.csv
            ].joined(separator: ","))
        }

        // Income Sources (+ optional schedules)
        for s in sources {
            let type = "IncomeSource"
            let name = s.name
            let amount = formatDecimal(s.defaultAmount)

            if let sch = s.schedule {
                let dateStr = formatDate(sch.anchorDate)
                let frequency = sch.frequency.rawValue
                rows.append([
                    type.csv, name.csv, amount.csv, dateStr.csv, frequency.csv, "".csv
                ].joined(separator: ","))
            } else {
                rows.append([
                    type.csv, name.csv, amount.csv, "".csv, "".csv, "".csv
                ].joined(separator: ","))
            }
        }

        // Write CSV
        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pps-data-\(UUID().uuidString).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw ExportError(message: "Failed to write CSV: \(error.localizedDescription)")
        }
        return url
    }

    // MARK: - Formatting

    private static func formatDate(_ d: Date?) -> String {
        guard let d else { return "" }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: d)
    }

    private static func formatDecimal(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: n) ?? "0"
    }
}

// MARK: - CSV escaping

private extension String {
    var csv: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"\(replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return self
    }
}
