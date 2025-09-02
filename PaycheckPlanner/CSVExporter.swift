//
//  CSVExporter.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Adds async variants that await a tiny delay after writing
//  to avoid a blank UIActivityViewController sheet on first presentation.
//
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum CSVExporter {

    // MARK: - Upcoming Paychecks CSV (per-period rows)

    /// Synchronous version (kept for backward-compat). Writes and returns a temp file URL.
    static func upcomingCSV(breakdowns: [CombinedBreakdown]) -> URL {
        var rows: [String] = ["Payday,Income,Bills,Remaining,Category,Item,Amount"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for b in breakdowns {
            let payday = df.string(from: b.period.payday)
            let income = b.incomeTotal
            let billsTotal = b.billsTotal
            let remaining = income + b.carryIn - billsTotal

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

    /// Async variant that ensures the file system is ready before you present a share sheet.
    static func upcomingCSVAsync(breakdowns: [CombinedBreakdown]) async -> URL {
        var rows: [String] = ["Payday,Income,Bills,Remaining,Category,Item,Amount"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for b in breakdowns {
            let payday = df.string(from: b.period.payday)
            let income = b.incomeTotal
            let billsTotal = b.billsTotal
            let remaining = income + b.carryIn - billsTotal

            if b.items.isEmpty {
                rows.append("\(payday),\(income.csv),\(billsTotal.csv),\(remaining.csv),,,")
            } else {
                for line in b.items {
                    let cat = line.bill.category.isEmpty ? "Uncategorized" : line.bill.category
                    rows.append("\(payday),\(income.csv),\(billsTotal.csv),\(remaining.csv),\(cat.csvEscaped),\(line.bill.name.csvEscaped),\(line.total.csv)")
                }
            }
        }
        return await writeCSVFileAsync(rows: rows, suggestedName: "UpcomingPaychecks.csv")
    }

    // MARK: - Bills CSV (flat list)

    static func billsCSV(bills: [Bill]) -> URL {
        var rows: [String] = ["Name,Amount,Recurrence,DueDate,Category"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for b in bills {
            let recur = b.recurrence.displayName
            let date = df.string(from: b.anchorDueDate)
            let cat = b.category.isEmpty ? "Uncategorized" : b.category
            rows.append("\(b.name.csvEscaped),\(b.amount.csv),\(recur.csvEscaped),\(date.csvEscaped),\(cat.csvEscaped)")
        }
        return writeCSVFile(rows: rows, suggestedName: "Bills.csv")
    }

    static func billsCSVAsync(bills: [Bill]) async -> URL {
        var rows: [String] = ["Name,Amount,Recurrence,DueDate,Category"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for b in bills {
            let recur = b.recurrence.displayName
            let date = df.string(from: b.anchorDueDate)
            let cat = b.category.isEmpty ? "Uncategorized" : b.category
            rows.append("\(b.name.csvEscaped),\(b.amount.csv),\(recur.csvEscaped),\(date.csvEscaped),\(cat.csvEscaped)")
        }
        return await writeCSVFileAsync(rows: rows, suggestedName: "Bills.csv")
    }

    // MARK: - Income Sources CSV (flat list with schedule info if available)

    static func incomeCSV(incomes: [IncomeSource]) -> URL {
        var rows: [String] = ["Name,DefaultAmount,Frequency,AnchorDate,Extra"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for s in incomes {
            let amount = s.defaultAmount
            if let sch = s.schedule {
                let freq = sch.frequency.displayName
                let date = df.string(from: sch.anchorDate)
                var extra = ""
                if sch.frequency == .semimonthly {
                    extra = "First=\(sch.semimonthlyFirstDay);Second=\(sch.semimonthlySecondDay)"
                }
                rows.append("\(s.name.csvEscaped),\(amount.csv),\(freq.csvEscaped),\(date.csvEscaped),\(extra.csvEscaped)")
            } else {
                rows.append("\(s.name.csvEscaped),\(amount.csv),\(String("—").csvEscaped),\(String("—").csvEscaped),\(String("—").csvEscaped)")
            }
        }
        return writeCSVFile(rows: rows, suggestedName: "IncomeSources.csv")
    }

    static func incomeCSVAsync(incomes: [IncomeSource]) async -> URL {
        var rows: [String] = ["Name,DefaultAmount,Frequency,AnchorDate,Extra"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

        for s in incomes {
            let amount = s.defaultAmount
            if let sch = s.schedule {
                let freq = sch.frequency.displayName
                let date = df.string(from: sch.anchorDate)
                var extra = ""
                if sch.frequency == .semimonthly {
                    extra = "First=\(sch.semimonthlyFirstDay);Second=\(sch.semimonthlySecondDay)"
                }
                rows.append("\(s.name.csvEscaped),\(amount.csv),\(freq.csvEscaped),\(date.csvEscaped),\(extra.csvEscaped)")
            } else {
                rows.append("\(s.name.csvEscaped),\(amount.csv),\(String("—").csvEscaped),\(String("—").csvEscaped),\(String("—").csvEscaped)")
            }
        }
        return await writeCSVFileAsync(rows: rows, suggestedName: "IncomeSources.csv")
    }

    // MARK: - “All” CSV (single file with Section column)

    /// Synchronous “everything” export.
    static func allCSV(breakdowns: [CombinedBreakdown], bills: [Bill], incomes: [IncomeSource]) -> URL {
        var rows: [String] = ["Section,Name,Amount,Recurrence,RecurrenceEnd,Date,Extra"]

        let iso = ISO8601DateFormatter()
        let sec = { (s: String) in s.csvEscaped }

        // Section: Upcoming Paychecks (rolled up)
        for b in breakdowns {
            rows.append([
                sec("Upcoming Paychecks"),
                sec("Payday"),
                (b.incomeTotal - b.billsTotal + b.carryIn).csv, // Remaining
                sec(""),
                sec(""),
                sec(iso.string(from: b.period.payday)),
                sec("Income=\(b.incomeTotal.currencyString); Bills=\(b.billsTotal.currencyString); CarryIn=\(b.carryIn.currencyString)")
            ].joined(separator: ","))

            // Category lines
            let grouped = Dictionary(grouping: b.items, by: { $0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category })
            for (cat, lines) in grouped {
                let total = lines.reduce(Decimal(0)) { $0 + $1.total }
                rows.append([
                    sec("Upcoming Paychecks"),
                    sec("Category: \(cat)"),
                    total.csv,
                    sec(""),
                    sec(""),
                    sec(iso.string(from: b.period.payday)),
                    sec("")
                ].joined(separator: ","))
            }
        }

        // Section: Bills
        for b in bills {
            rows.append([
                sec("Bills"),
                b.name.csvEscaped,
                b.amount.csv,
                b.recurrence.displayName.csvEscaped,
                sec(""),
                sec(iso.string(from: b.anchorDueDate)),
                (b.category.isEmpty ? "Uncategorized" : b.category).csvEscaped
            ].joined(separator: ","))
        }

        // Section: Income Sources
        for s in incomes {
            if let sch = s.schedule {
                let extra = sch.frequency == .semimonthly ? "First=\(sch.semimonthlyFirstDay);Second=\(sch.semimonthlySecondDay)" : ""
                rows.append([
                    sec("Income"),
                    s.name.csvEscaped,
                    s.defaultAmount.csv,
                    sch.frequency.displayName.csvEscaped,
                    sec(""),
                    sec(iso.string(from: sch.anchorDate)),
                    sec(extra)
                ].joined(separator: ","))
            } else {
                rows.append([
                    sec("Income"),
                    s.name.csvEscaped,
                    s.defaultAmount.csv,
                    sec(""),
                    sec(""),
                    sec(""),
                    sec("")
                ].joined(separator: ","))
            }
        }

        return writeCSVFile(rows: rows, suggestedName: "All.csv")
    }

    /// Async “everything” export (preferred when immediately presenting a share sheet).
    static func allCSVAsync(breakdowns: [CombinedBreakdown], bills: [Bill], incomes: [IncomeSource]) async -> URL {
        var rows: [String] = ["Section,Name,Amount,Recurrence,RecurrenceEnd,Date,Extra"]

        let iso = ISO8601DateFormatter()
        let sec = { (s: String) in s.csvEscaped }

        // Section: Upcoming Paychecks (rolled up)
        for b in breakdowns {
            rows.append([
                sec("Upcoming Paychecks"),
                sec("Payday"),
                (b.incomeTotal - b.billsTotal + b.carryIn).csv, // Remaining
                sec(""),
                sec(""),
                sec(iso.string(from: b.period.payday)),
                sec("Income=\(b.incomeTotal.currencyString); Bills=\(b.billsTotal.currencyString); CarryIn=\(b.carryIn.currencyString)")
            ].joined(separator: ","))

            let grouped = Dictionary(grouping: b.items, by: { $0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category })
            for (cat, lines) in grouped {
                let total = lines.reduce(Decimal(0)) { $0 + $1.total }
                rows.append([
                    sec("Upcoming Paychecks"),
                    sec("Category: \(cat)"),
                    total.csv,
                    sec(""),
                    sec(""),
                    sec(iso.string(from: b.period.payday)),
                    sec("")
                ].joined(separator: ","))
            }
        }

        // Section: Bills
        for b in bills {
            rows.append([
                sec("Bills"),
                b.name.csvEscaped,
                b.amount.csv,
                b.recurrence.displayName.csvEscaped,
                sec(""),
                sec(iso.string(from: b.anchorDueDate)),
                (b.category.isEmpty ? "Uncategorized" : b.category).csvEscaped
            ].joined(separator: ","))
        }

        // Section: Income Sources
        for s in incomes {
            if let sch = s.schedule {
                let extra = sch.frequency == .semimonthly ? "First=\(sch.semimonthlyFirstDay);Second=\(sch.semimonthlySecondDay)" : ""
                rows.append([
                    sec("Income"),
                    s.name.csvEscaped,
                    s.defaultAmount.csv,
                    sch.frequency.displayName.csvEscaped,
                    sec(""),
                    sec(iso.string(from: sch.anchorDate)),
                    sec(extra)
                ].joined(separator: ","))
            } else {
                rows.append([
                    sec("Income"),
                    s.name.csvEscaped,
                    s.defaultAmount.csv,
                    sec(""),
                    sec(""),
                    sec(""),
                    sec("")
                ].joined(separator: ","))
            }
        }

        return await writeCSVFileAsync(rows: rows, suggestedName: "All.csv")
    }
}

// MARK: - Helpers (Writing)

/// Synchronous write. Keeps existing behavior for callers that don’t present immediately.
private func writeCSVFile(rows: [String], suggestedName: String) -> URL {
    let data = rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    let dir = FileManager.default.temporaryDirectory
    let url = dir.appendingPathComponent(suggestedName)

    // Atomic write (temp file -> move) to reduce partial reads.
    do {
        try data.write(to: url, options: [.atomic])
        // Touch the file attributes to encourage the system to surface it right away.
        _ = try? url.checkResourceIsReachable()
    } catch {
        // If write fails, still return the intended URL for caller error handling/logging.
        #if DEBUG
        print("CSV write failed for \(suggestedName): \(error)")
        #endif
    }
    return url
}

/// Async write + tiny delay so the share sheet never opens on a not-quite-ready file.
private func writeCSVFileAsync(rows: [String], suggestedName: String) async -> URL {
    let url = writeCSVFile(rows: rows, suggestedName: suggestedName)
    // Give iOS a brief moment to register/index the new file (prevents blank sheet).
    try? await Task.sleep(nanoseconds: 150_000_000) // ~0.15s
    return url
}

// MARK: - Formatting Extensions

private extension Decimal {
    var csv: String {
        // Use dot-decimal; plain number, not currency
        let n = self as NSDecimalNumber
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        f.locale = Locale(identifier: "en_US_POSIX")
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

// MARK: - ShareSheet

/// Simple UIActivityViewController wrapper for sharing files
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
