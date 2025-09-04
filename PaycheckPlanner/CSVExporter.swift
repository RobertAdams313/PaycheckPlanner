//
//  CSVExporter.swift
//  PaycheckPlanner
//
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CSVExporter {

    // MARK: - Upcoming Paychecks CSV (per-period rows)

    static func upcomingCSV(breakdowns: [CombinedBreakdown]) -> URL {
        var rows: [String] = ["Payday,Income,Bills,Remaining,Category,Item,Amount"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for b in breakdowns {
            let payday = df.string(from: b.period.payday)
            let income = b.incomeTotal
            let billsTotal = b.billsTotal
            let remaining = income + b.carryIn - b.billsTotal

            if b.items.isEmpty {
                rows.append("\(payday),\(income.csv),\(billsTotal.csv),\(remaining.csv),,,")
            } else {
                for line in b.items {
                    let cat = line.bill.category.isEmpty ? "Uncategorized" : line.bill.category
                    rows.append("\(payday),\(income.csv),\(billsTotal.csv),\(remaining.csv),\(cat.csvEscaped),\(line.bill.name.csvEscaped),\(line.total.csv)")
                }
            }
        }
        return writeCSVFile(rows: rows, suggestedName: "UpcomingPaychecks.csv")
    }

    static func upcomingCSVAsync(breakdowns: [CombinedBreakdown]) async -> URL {
        let url = upcomingCSV(breakdowns: breakdowns)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        return url
    }

    // MARK: - Bills CSV

    static func billsCSV(bills: [Bill]) -> URL {
        var rows = ["Name,Amount,Category,Due Date,Recurrence"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for b in bills {
            let name = b.name.csvEscaped
            let amount = b.amount.csv
            let category = (b.category.isEmpty ? "Uncategorized" : b.category).csvEscaped
            let due = df.string(from: b.anchorDueDate)
            let rec = b.recurrence.rawValue
            rows.append("\(name),\(amount),\(category),\(due),\(rec)")
        }
        return writeCSVFile(rows: rows, suggestedName: "Bills.csv")
    }

    static func billsCSVAsync(bills: [Bill]) async -> URL {
        let url = billsCSV(bills: bills)
        try? await Task.sleep(nanoseconds: 50_000_000)
        return url
    }

    // MARK: - Income CSV (keeps columns minimal and resilient)
    // We only rely on 'name' existing on IncomeSource.
    // If an amount-like property exists (amount/netAmount/baseAmount), we include it.

    static func incomeCSV(incomes: [IncomeSource]) -> URL {
        var rows = ["Name,Amount"]
        for src in incomes {
            let (hasAmount, amountString) = reflectedAmountString(src)
            if hasAmount {
                rows.append("\(src.name.csvEscaped),\(amountString)")
            } else {
                rows.append("\(src.name.csvEscaped),")
            }
        }
        return writeCSVFile(rows: rows, suggestedName: "Income.csv")
    }

    // MARK: - All-in-one CSV (single file with 3 sections)
    // Produces a single CSV file with section headers and each dataset below it.
    // This avoids needing a ZIP container while keeping things simple to share.

    static func allCSV(
        breakdowns: [CombinedBreakdown],
        bills: [Bill],
        incomes: [IncomeSource]
    ) -> URL {
        // Build each CSV as strings (reuse writers for consistent headers/formatting)
        let upcomingURL = upcomingCSV(breakdowns: breakdowns)
        let billsURL    = billsCSV(bills: bills)
        let incomeURL   = incomeCSV(incomes: incomes)

        let upcoming = (try? String(contentsOf: upcomingURL)) ?? ""
        let billsS   = (try? String(contentsOf: billsURL)) ?? ""
        let incomeS  = (try? String(contentsOf: incomeURL)) ?? ""

        var combined: [String] = []
        combined.append("# Upcoming Paychecks")
        combined.append(upcoming)
        combined.append("") // blank line
        combined.append("# Bills")
        combined.append(billsS)
        combined.append("")
        combined.append("# Income")
        combined.append(incomeS)

        let csv = combined.joined(separator: "\n")
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("AllExport.csv", conformingTo: .commaSeparatedText)
        try? csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Private

    private static func writeCSVFile(rows: [String], suggestedName: String) -> URL {
        let csv = rows.joined(separator: "\n")
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(suggestedName, conformingTo: .commaSeparatedText)
        try? csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    /// Attempts to extract a Decimal-like amount from an IncomeSource via reflection.
    /// Supports common property names without requiring compile-time knowledge.
    private static func reflectedAmountString(_ src: IncomeSource) -> (Bool, String) {
        // Look for common names you’ve used across iterations.
        let candidates = ["amount", "netAmount", "baseAmount", "grossAmount"]
        let mirror = Mirror(reflecting: src)

        for child in mirror.children {
            guard let label = child.label else { continue }
            if candidates.contains(label) {
                if let d = child.value as? Decimal {
                    return (true, d.csv)
                }
                if let n = child.value as? NSDecimalNumber {
                    return (true, (n as Decimal).csv)
                }
                if let d = child.value as? Double {
                    return (true, Decimal(d).csv)
                }
                if let s = child.value as? String, !s.isEmpty {
                    // Assume already a currency-like string
                    return (true, s.csvEscaped)
                }
            }
        }
        return (false, "")
    }
}

// MARK: - UIKit ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
