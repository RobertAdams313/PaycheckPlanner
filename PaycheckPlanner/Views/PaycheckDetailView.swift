//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//

import SwiftUI
import SwiftData

/// Shows full details for a single combined period: incomes, bills, and remaining.
struct PaycheckDetailView: View {
    let breakdown: CombinedBreakdown

    var body: some View {
        List {
            Section {
                summaryRows
            }

            Section("Incomes") {
                ForEach(breakdown.period.incomes) { inc in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(inc.source.name.isEmpty ? "Untitled income" : inc.source.name)
                            Text(incomeSubtitle(for: inc))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatCurrency(inc.amount))
                            .monospacedDigit()
                    }
                }
            }

            Section {
                ForEach(breakdown.items) { line in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.bill.name.isEmpty ? "Untitled bill" : line.bill.name)
                            Text("\(line.bill.recurrence.uiName) • due \(uiMonthDay(line.bill.anchorDueDate))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if line.occurrences > 1 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(line.occurrences) × \(formatCurrency(line.amountEach))")
                                    .monospacedDigit()
                                Text(formatCurrency(line.total))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(formatCurrency(line.total))
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                Text("Bills")
            } footer: {
                runningBalanceFooter
            }

            Section {
                HStack {
                    Text("Remaining").bold()
                    Spacer()
                    Text(formatCurrency(breakdown.leftover)).bold()
                        .monospacedDigit()
                }
                .accessibilityLabel("Remaining")
            }
        }
        .navigationTitle(uiDateIntervalString(breakdown.period.start, breakdown.period.end))
    }

    // MARK: - Running Balance

    private var runningBalanceFooter: some View {
        let events = billOccurrenceEvents()
        let start = breakdown.incomeTotal + breakdown.carryIn
        let steps = runningBalanceSteps(events: events, start: start)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Start (Income + Carry-in)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(start)).monospacedDigit()
            }

            ForEach(steps, id: \.0.id) { e, balanceAfter in
                HStack(alignment: .firstTextBaseline) {
                    Text("− \(e.title) — \(uiMonthDay(e.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("− \(formatCurrency(e.amount))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(balanceAfter))
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Running balance")
    }

    private func runningBalanceSteps(events: [BillEvent], start: Decimal) -> [(BillEvent, Decimal)] {
        var bal = start
        return events.map { ev in
            bal -= ev.amount
            return (ev, bal)
        }
    }

    private struct BillEvent: Identifiable {
        let id = UUID()
        let date: Date
        let amount: Decimal
        let title: String
    }

    /// Expand each bill line into per-occurrence events strictly inside (start, end).
    private func billOccurrenceEvents() -> [BillEvent] {
        let start = breakdown.period.start
        let end   = breakdown.period.end
        let cal = Calendar(identifier: .gregorian)

        func strideDates(from anchor: Date, everyDays: Int) -> [Date] {
            var d = anchor
            while d <= start {
                d = cal.date(byAdding: .day, value: everyDays, to: d)
                    ?? d.addingTimeInterval(Double(everyDays) * 86400)
            }
            var out: [Date] = []
            while d < end {                        // strictly before end
                out.append(d)
                d = cal.date(byAdding: .day, value: everyDays, to: d)
                    ?? d.addingTimeInterval(Double(everyDays) * 86400)
            }
            return out
        }

        func monthlyDates(anchor: Date) -> [Date] {
            let day = max(1, min(28, cal.component(.day, from: anchor)))
            var comps = cal.dateComponents([.year, .month], from: start)
            var out: [Date] = []
            while true {
                guard let y = comps.year, let m = comps.month else { break }
                var c = DateComponents(); c.year = y; c.month = m; c.day = day
                if let d = cal.date(from: c), d > start && d < end { out.append(d) }
                comps.month = m + 1
                if (cal.date(from: comps) ?? end) >= end { break }
            }
            return out
        }

        func semiMonthlyDates(anchor: Date) -> [Date] {
            let aDay = cal.component(.day, from: anchor)
            let d1 = aDay <= 15 ? max(1, min(28, aDay)) : 1
            let d2 = aDay <= 15 ? 30 : max(1, min(28, aDay))
            let days = [d1, d2].sorted()
            var comps = cal.dateComponents([.year, .month], from: start)
            var out: [Date] = []
            while true {
                guard let y = comps.year, let m = comps.month else { break }
                for dd in days {
                    var c = DateComponents(); c.year = y; c.month = m; c.day = dd
                    if let d = cal.date(from: c), d > start && d < end { out.append(d) }
                }
                comps.month = m + 1
                if (cal.date(from: comps) ?? end) >= end { break }
            }
            return out
        }

        var events: [BillEvent] = []
        for line in breakdown.items {
            let b = line.bill
            let dates: [Date]
            switch b.recurrence {
            case .once:
                dates = (b.anchorDueDate > start && b.anchorDueDate < end) ? [b.anchorDueDate] : []
            case .weekly:
                dates = strideDates(from: b.anchorDueDate, everyDays: 7)
            case .biweekly:
                dates = strideDates(from: b.anchorDueDate, everyDays: 14)
            case .monthly:
                dates = monthlyDates(anchor: b.anchorDueDate)
            case .semimonthly:
                dates = semiMonthlyDates(anchor: b.anchorDueDate)
            }
            for d in dates {
                events.append(.init(date: d, amount: b.amount, title: b.name.isEmpty ? "Bill" : b.name))
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    // MARK: - Summary + formatting

    @ViewBuilder private var summaryRows: some View {
        HStack {
            labelValue("Income", formatCurrency(breakdown.incomeTotal))
            Spacer(minLength: 16)
            labelValue("Bills", formatCurrency(breakdown.billsTotal))
            Spacer(minLength: 16)
            labelValue("Remaining", formatCurrency(breakdown.leftover))
        }
        if breakdown.carryIn != 0 {
            HStack {
                Text("Carry-in")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(breakdown.carryIn))
                    .monospacedDigit()
            }
            .accessibilityLabel("Carry in")
        }
    }

    private func incomeSubtitle(for inc: PeriodIncome) -> String {
        // If the source has a schedule, prefer its UI frequency; otherwise “Variable” if flagged.
        if let freq = inc.source.schedule?.frequency {
            return freq.uiName
        }
        return inc.source.variable ? "Variable" : ""
    }

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) { Text(label).foregroundStyle(.secondary); Text(value).bold() }
    }

    private func formatCurrency(_ value: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: value)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}
