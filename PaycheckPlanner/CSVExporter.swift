//
//  CSVExporter.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CSVExporter {
    static func upcomingCSV(breakdowns: [CombinedBreakdown]) -> URL {
        var rows: [String] = ["Payday,Income,Bills,Leftover,Category,Item,Amount"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for b in breakdowns {
            let payday = df.string(from: b.period.payday)
            let income = b.incomeTotal
            let billsTotal = b.billsTotal
            let leftover = income - billsTotal

            if b.items.isEmpty {
                rows.append("\(payday),\(income.csv),\(billsTotal.csv),\(leftover.csv),,,")
            } else {
                for i in b.items {
                    let cat = i.bill.category.isEmpty ? "Uncategorized" : i.bill.category
                    rows.append("\(payday),\(income.csv),\(billsTotal.csv),\(leftover.csv),\(cat.csvEscaped),\(i.bill.name.csvEscaped),\(i.total.csv)")
                }
            }
        }
        return writeCSV(named: "UpcomingPaychecks.csv", rows: rows)
    }

    static func billsCSV(bills: [Bill]) -> URL {
        var rows = ["Name,Amount,Recurrence,AnchorDueDate,Category"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for b in bills {
            rows.append("\(b.name.csvEscaped),\(b.amount.csv),\(b.recurrence.rawValue.csvEscaped),\(df.string(from: b.anchorDueDate)),\(b.category.csvEscaped)")
        }
        return writeCSV(named: "Bills.csv", rows: rows)
    }

    static func incomeCSV(incomes: [IncomeSource]) -> URL {
        var rows = ["Name,DefaultAmount,Variable,Frequency,AnchorDate,Semi1,Semi2"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        for s in incomes {
            let f = s.schedule?.frequency.rawValue ?? ""
            let ad = s.schedule?.anchorDate != nil ? df.string(from: s.schedule!.anchorDate) : ""
            let d1 = s.schedule?.semimonthlyFirstDay ?? 0
            let d2 = s.schedule?.semimonthlySecondDay ?? 0
            rows.append("\(s.name.csvEscaped),\(s.defaultAmount.csv),\(s.variable ? "true" : "false"),\(f.csvEscaped),\(ad),\(d1),\(d2)")
        }
        return writeCSV(named: "Income.csv", rows: rows)
    }

    // MARK: - helpers

    private static func writeCSV(named: String, rows: [String]) -> URL {
        let csv = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(named)
        try? csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }
}

// Formatting helpers
private extension Decimal {
    var csv: String {
        let n = NSDecimalNumber(decimal: self)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "0"
    }
}

private extension String {
    var csvEscaped: String {
        if contains(",") || contains("\"") || contains("\n") {
            return "\"\(replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return self
    }
}

// Simple UIActivityViewController wrapper for sharing files
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
