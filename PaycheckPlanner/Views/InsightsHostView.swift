

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

    @AppStorage("planPeriodCount") private var planCount: Int = 4
    @State private var showExport = false
    @State private var exportURL: URL?
    @State private var selectedCategory: String?

    private var breakdowns: [CombinedBreakdown] {
        let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: max(planCount, 1))
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    private var totals: (income: Decimal, bills: Decimal, remaining: Decimal) {
        let income = breakdowns.reduce(0) { $0 + $1.incomeTotal }
        let billsT = breakdowns.reduce(0) { $0 + $1.billsTotal }
        let carry = breakdowns.reduce(0) { $0 + $1.carryIn }
        return (income, billsT, income + carry - billsT)
    }

    // Category slices across the window (sorted by amount desc, stable)
    private var categorySlices: [(category: String, amount: Decimal)] {
        let lines = breakdowns.flatMap(\.items)
        let grouped = Dictionary(grouping: lines, by: { ($0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category) })
        return grouped
            .map { (key, vals) in (category: key, amount: vals.reduce(0) { $0 + $1.total }) }
            .sorted { $0.amount > $1.amount }
            .filter { $0.amount > 0 }
    }

    // Bills per category for the “details pop-down”
    private var billsByCategory: [String: [AllocatedBillLine]] {
        let all = breakdowns.flatMap(\.items)
        return Dictionary(grouping: all, by: { $0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category })
    }

    // Income sources list (for export)
    private var incomeSources: [IncomeSource] {
        // prefer unique sources from schedules if you want to de-dupe
        let set = Set(schedules.compactMap { $0.source })
        return Array(set).sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                // SUMMARY
                Section("Summary (next \(breakdowns.count) paychecks)") {
                    summaryRow(label: "Income", value: totals.income)
                    summaryRow(label: "Bills", value: totals.bills)
                    summaryRow(label: "Remaining", value: totals.remaining, bold: true)
                }

                // SPENDING BY CATEGORY (donut + fixed-order list; donut non-interactive)
                if !categorySlices.isEmpty {
                    Section("Spending by Category") {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.quaternary)
                            VStack(spacing: 12) {
                                donutView
                                categoryList
                                if let cat = selectedCategory, let lines = billsByCategory[cat], !lines.isEmpty {
                                    DisclosureGroup("Details: \(cat)") {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(lines) { line in
                                                HStack {
                                                    Text(line.bill.name)
                                                    Spacer()
                                                    Text(formatCurrency(line.total)).monospacedDigit()
                                                }
                                                .font(.subheadline)
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                    .disclosureGroupStyle(.automatic)
                                }
                            }
                            .padding(12)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Spending by Category chart and list")
                    }
                }

                // UPCOMING PERIODS (reduce duplication—keep a clean row)
                if !breakdowns.isEmpty {
                    Section("Upcoming Paychecks") {
                        ForEach(breakdowns) { b in
                            NavigationLink {
                                PaycheckDetailView(breakdown: b)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(b.period.payday, format: .dateTime.month().day().year())
                                            .font(.body)
                                            .fontWeight(.semibold)
                                        Text("\(b.period.incomes.count) source\(b.period.incomes.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Bills \(formatCurrency(b.billsTotal))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatCurrency(b.incomeTotal + b.carryIn - b.billsTotal))
                                            .bold()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
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
                        Divider()
                        Button("Export All (CSV)") {
                            exportURL = CSVExporter.allCSV(
                                breakdowns: breakdowns,
                                bills: bills,
                                incomes: incomeSources
                            )
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

    // MARK: - Donut + list

    private var donutView: some View {
        let total = categorySlices.reduce(Decimal(0)) { $0 + $1.amount }
        return Chart(categorySlices, id: \.category) { item in
            let value = NSDecimalNumber(decimal: item.amount).doubleValue
            SectorMark(
                angle: .value("Amount", value),
                innerRadius: .ratio(0.60)
            )
            .foregroundStyle(by: .value("Category", item.category))
            .opacity(selectedCategory == nil || selectedCategory == item.category ? 1.0 : 0.33)
            .annotation(position: .overlay, alignment: .center) {
                // Percent inside the wedge (hide tiny slivers)
                let pct = (total == 0) ? 0 : (item.amount / total * 100)
                if pct >= 5 {
                    Text("\(Int((pct as NSDecimalNumber).doubleValue.rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .shadow(radius: 1)
                }
            }
        }
        .frame(height: 220)
        .chartLegend(.hidden) // We provide our own stable list
        .accessibilityLabel("Bills by category")
    }

    private var categoryList: some View {
        VStack(spacing: 8) {
            ForEach(categorySlices, id: \.category) { s in
                Button {
                    withAnimation(.snappy) {
                        selectedCategory = (selectedCategory == s.category) ? nil : s.category
                    }
                } label: {
                    HStack {
                        // Color well that matches chart’s mapping
                        Circle()
                            .fill(Color.accentColor) // placeholder; Charts assigns a palette automatically
                            .frame(width: 10, height: 10)
                            .overlay(
                                // Improve mapping by using a label; we’ll keep it simple
                                Circle().strokeBorder(.quaternary)
                            )

                        Text(s.category)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(formatCurrency(s.amount))
                            .font(.subheadline).monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                    .opacity(selectedCategory == nil || selectedCategory == s.category ? 1.0 : 0.5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Summary row

    private func summaryRow(label: String, value: Decimal, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
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
