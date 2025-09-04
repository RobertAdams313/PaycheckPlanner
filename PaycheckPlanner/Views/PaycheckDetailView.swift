//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25
//

import SwiftUI
import SwiftData

// MARK: - Lightweight value rows (avoid Binding/bridging confusion)

private struct IncomeRowData: Identifiable {
    let id: UUID
    let name: String
    let paidDate: Date
    let amount: Decimal
}

private struct BillRowData: Identifiable {
    let id: UUID
    let title: String
    let category: String?
    let dueDates: [Date]     // all due dates inside the period [start, end)
    let amountEach: Decimal
    let occurrences: Int
    let total: Decimal
}

// MARK: - Shared card container (matches PlanView)

private struct CardRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
                .padding(14)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.separator.opacity(0.15))
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

// MARK: - View

/// Shows full details for a single combined period: income, bills, and remaining.
struct PaycheckDetailView: View {
    @Environment(\.modelContext) private var context
    let breakdown: CombinedBreakdown

    var body: some View {
        List {
            // SUMMARY
            Section {
                summaryCard()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // INCOME (card-like)
            Section("Income") { // ← renamed from "Incomes"
                let rows: [IncomeRowData] = breakdown.period.incomes.map { inc in
                    IncomeRowData(
                        id: inc.id,
                        name: inc.source.name.isEmpty ? "Untitled Income" : inc.source.name,
                        // PeriodIncome doesn't carry its own date — show this period’s payday
                        paidDate: breakdown.period.payday,
                        amount: inc.amount
                    )
                }

                ForEach(rows) { row in
                    incomeCard(name: row.name, paidDate: row.paidDate, amount: row.amount)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // BILLS (card-like, with "Due ..." and sorted by most-recently due first)
            Section("Bills") {
                // Map → then sort by most-recently due first (latest date desc) in one expression
                let rows: [BillRowData] = billsRowsSortedMostRecentFirst()

                ForEach(rows) { row in
                    billCard(row: row)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Paycheck Details")
    }

    // MARK: - Card builders

    private func summaryCard() -> some View {
        let carryIn   = breakdown.carryIn
        let income    = breakdown.incomeTotal
        let startBal  = income + carryIn
        let billsSum  = breakdown.billsTotal
        let remaining = startBal - billsSum

        return CardRow {
            VStack(alignment: .leading, spacing: 10) {
                Text(formatDateRange(start: breakdown.period.start, end: breakdown.period.end))
                    .font(.headline)

                HStack(spacing: 16) {
                    labeledValue("Income", value: formatCurrency(income))
                    labeledValue("Bills", value: formatCurrency(billsSum))
                    labeledValue("Remaining", value: formatCurrency(remaining))
                }
                .font(.subheadline)

                if carryIn != 0 {
                    carryInBadge(carryIn)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func incomeCard(name: String, paidDate: Date, amount: Decimal) -> some View {
        CardRow {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text("Paid " + mediumDate(paidDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatCurrency(amount))
                    .bold()
                    .monospacedDigit()
            }
        }
    }

    private func billCard(row: BillRowData) -> some View {
        CardRow {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .lineLimit(2)
                        .truncationMode(.tail)

                    if let category = row.category {
                        Text(category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // If multiple occurrences, show "amountEach × N"
                    if row.occurrences > 1 {
                        Text("\(formatCurrency(row.amountEach)) × \(row.occurrences)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    if !row.dueDates.isEmpty {
                        Text("Due " + joinedShortDates(row.dueDates)) // ← clarity label
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(formatCurrency(row.total))
                        .bold()
                        .monospacedDigit()
                }
            }
        }
    }

    private func labeledValue(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .bold()
                .monospacedDigit()
        }
    }

    // MARK: - Bill rows (mapping + sorting)

    private func billsRowsSortedMostRecentFirst() -> [BillRowData] {
        let cal = Calendar(identifier: .gregorian)
        return breakdown.items
            .map { line in
                let b = line.bill
                let dates = dueDates(for: b, in: breakdown.period, cal: cal)
                return BillRowData(
                    id: line.id,
                    title: b.name,
                    category: b.category.isEmpty ? nil : b.category,
                    dueDates: dates,
                    amountEach: line.amountEach,
                    occurrences: line.occurrences,
                    total: line.total
                )
            }
            .sorted { a, b in
                // Sort by latest due date DESC; items with no due date go to the bottom.
                (a.dueDates.max() ?? .distantPast) < (b.dueDates.max() ?? .distantPast)
            }
    }

    // MARK: - Due dates inside [period.start, period.end)

    /// Compute all due dates for a bill inside the given period (start-inclusive, end-exclusive),
    /// mirroring the allocation rules without touching the engine.
    private func dueDates(for bill: Bill, in period: CombinedPeriod, cal: Calendar) -> [Date] {
        let start = cal.startOfDay(for: period.start)
        let end   = cal.startOfDay(for: period.end)

        switch bill.recurrence {
        case .once:
            let d = cal.startOfDay(for: bill.anchorDueDate)
            return (d >= start && d < end) ? [d] : []

        case .weekly:
            return strideDates(from: bill.anchorDueDate, everyDays: 7, in: start, end, cal: cal)

        case .biweekly:
            return strideDates(from: bill.anchorDueDate, everyDays: 14, in: start, end, cal: cal)

        case .monthly:
            let day = max(1, min(28, cal.component(.day, from: bill.anchorDueDate)))
            return monthlyDates(day: day, in: start, end, cal: cal)

        case .semimonthly:
            let aDay = cal.component(.day, from: bill.anchorDueDate)
            // keep parity logic consistent with your allocator
            let (d1, d2) = aDay <= 15 ? (max(1, min(28, aDay)), 30) : (1, max(1, min(28, aDay)))
            return semiMonthlyDates(d1: d1, d2: d2, in: start, end, cal: cal)
        }
    }

    private func strideDates(from anchor: Date, everyDays: Int, in start: Date, _ end: Date, cal: Calendar) -> [Date] {
        var d = cal.startOfDay(for: anchor)
        while d < start {
            d = cal.date(byAdding: .day, value: everyDays, to: d)
                ?? d.addingTimeInterval(Double(everyDays) * 86400)
        }
        var out: [Date] = []
        while d < end {
            out.append(d)
            d = cal.date(byAdding: .day, value: everyDays, to: d)
                ?? d.addingTimeInterval(Double(everyDays) * 86400)
        }
        return out
    }

    private func monthlyDates(day: Int, in start: Date, _ end: Date, cal: Calendar) -> [Date] {
        let dayClamped = max(1, min(28, day))
        var comps = cal.dateComponents([.year, .month], from: start)
        var out: [Date] = []
        while true {
            guard let y = comps.year, let m = comps.month else { break }
            var c = DateComponents(); c.year = y; c.month = m; c.day = dayClamped
            if let d = cal.date(from: c), d >= start && d < end { out.append(d) }
            comps.month = m + 1
            if (cal.date(from: comps) ?? end) >= end { break }
        }
        return out
    }

    private func semiMonthlyDates(d1: Int, d2: Int, in start: Date, _ end: Date, cal: Calendar) -> [Date] {
        let days = [max(1, min(28, d1)), max(1, min(28, d2))].sorted()
        var comps = cal.dateComponents([.year, .month], from: start)
        var out: [Date] = []
        while true {
            guard let y = comps.year, let m = comps.month else { break }
            for dd in days {
                var c = DateComponents(); c.year = y; c.month = m; c.day = dd
                if let d = cal.date(from: c), d >= start && d < end { out.append(d) }
            }
            comps.month = m + 1
            if (cal.date(from: comps) ?? end) >= end { break }
        }
        return out
    }

    // MARK: - Formatting & small pieces (mirrors PlanView)

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }

    private func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    private func joinedShortDates(_ dates: [Date]) -> String {
        guard !dates.isEmpty else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return dates.map { f.string(from: $0) }.joined(separator: ", ")
    }

    /// Keep this identical to PlanView so ranges match visually
    private func formatDateRange(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let sComp = cal.dateComponents([.year, .month, .day], from: start)
        let eComp = cal.dateComponents([.year, .month, .day], from: end)

        let dfDay = DateFormatter(); dfDay.dateFormat = "d"
        let dfMonth = DateFormatter.cached("MMM")
        let dfMonthDay = DateFormatter(); dfMonthDay.dateFormat = "MMM d"
        let dfMonthDayYear = DateFormatter(); dfMonthDayYear.dateFormat = "MMM d, yyyy"

        if sComp.year != eComp.year {
            return "\(dfMonthDayYear.string(from: start))–\(dfMonthDayYear.string(from: end))"
        }
        if sComp.month == eComp.month {
            return "\(dfMonth.string(from: start)) \(dfDay.string(from: start))–\(dfDay.string(from: end)), \(sComp.year!)"
        } else {
            return "\(dfMonthDay.string(from: start))–\(dfMonthDay.string(from: end)), \(sComp.year!)"
        }
    }

    @ViewBuilder
    private func carryInBadge(_ amount: Decimal) -> some View {
        let positive = amount >= 0
        let label = positive ? "Carry-in" : "Carry-over"
        let display = positive ? "+\(formatCurrency(amount))" : formatCurrency(amount)

        HStack(spacing: 6) {
            Image(systemName: positive ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                .imageScale(.small)
            Text("\(label) \(display)")
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
    }
}

// Keep the cached DateFormatter helper at file scope
    extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = fmt
        return df
    }
}
