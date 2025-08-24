//
//  InsightsHostView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData
import Charts

struct InsightsHostView: View {
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]
    @Query(sort: \IncomeSource.name, order: .forward) private var incomeSources: [IncomeSource]

    @AppStorage("planPeriodCount") private var planCount: Int = 4
    @State private var showExport = false
    @State private var exportURL: URL?

    private var breakdowns: [CombinedBreakdown] {
        let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: max(planCount, 1))
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    // Totals across the window
    private var totals: (income: Decimal, bills: Decimal, leftover: Decimal) {
        let income = breakdowns.reduce(0) { $0 + $1.incomeTotal }
        let billsT = breakdowns.reduce(0) { $0 + $1.billsTotal }
        return (income, billsT, income - billsT)
    }

    // Category → total amount in the window
    private var categorySlices: [(category: String, amount: Decimal)] {
        let lines = breakdowns.flatMap(\.items)
        let grouped = Dictionary(grouping: lines, by: { ($0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category) })
        return grouped
            .map { (key, vals) in (category: key, amount: vals.reduce(0) { $0 + $1.total }) }
            .sorted { $0.amount > $1.amount }
            .filter { $0.amount > 0 }
    }

    var body: some View {
        NavigationStack {
            List {
                // SUMMARY
                Section("Summary (next \(breakdowns.count) paychecks)") {
                    summaryRow(label: "Income", value: totals.income)
                    summaryRow(label: "Bills",  value: totals.bills)
                    summaryRow(label: "Leftover", value: totals.leftover, bold: true)
                }

                // PIE / DONUT CHART (HIG: no text over the marks; legend + list for clarity)
                if !categorySlices.isEmpty {
                    Section("Bills by Category") {
                        VStack(alignment: .center, spacing: 8) {
                            Chart(categorySlices, id: \.category) { item in
                                let value = NSDecimalNumber(decimal: item.amount).doubleValue
                                SectorMark(angle: .value("Amount", value),
                                           innerRadius: .ratio(0.60))
                                .foregroundStyle(by: .value("Category", item.category))
                            }
                            .frame(height: 220)
                            .chartLegend(.automatic) // clear mapping per HIG
                            .accessibilityLabel("Bills by category")

                            // Text list (outside the donut) for precise reading
                            ForEach(categorySlices, id: \.category) { s in
                                HStack {
                                    Text(s.category)
                                    Spacer()
                                    Text(formatCurrency(s.amount)).bold()
                                }
                            }
                        }
                    }
                }

                // PER PAYCHECK (tap to details)
                Section("By Paycheck") {
                    ForEach(breakdowns) { b in
                        NavigationLink {
                            PaycheckDetailView(breakdown: b)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(b.period.payday, format: .dateTime.month().day().year())
                                    Text("\(b.period.incomes.count) source\(b.period.incomes.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Bills \(formatCurrency(b.billsTotal))").font(.caption)
                                    Text(formatCurrency(b.incomeTotal - b.billsTotal)).bold()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Export Upcoming Paychecks (CSV)") {
                            exportURL = CSVExporter.upcomingCSV(breakdowns: breakdowns)
                            showExport = true
                        }
                        Button("Export Bills (CSV)") {
                            exportURL = CSVExporter.billsCSV(bills: bills)
                            showExport = true
                        }
                        Button("Export Income Sources (CSV)") {
                            exportURL = CSVExporter.incomeCSV(incomes: incomeSources)
                            showExport = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showExport) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private func summaryRow(label: String, value: Decimal, bold: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            if bold { Text(formatCurrency(value)).bold() }
            else { Text(formatCurrency(value)) }
        }
    }

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}
