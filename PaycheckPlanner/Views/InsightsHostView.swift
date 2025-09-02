//
//  InsightsHostView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Insights: centered summary, persistent legend with dim + quick view,
//  no gray backgrounds, small header-style coverage line under title.
//  Updated on 9/2/25 (Card UI): Wrap primary groups in blur cards to match Plan/Bills,
//  without changing behaviors or layout intent.
//
import SwiftUI
import SwiftData
import Charts

struct InsightsHostView: View {
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    @AppStorage("planPeriodCount") private var planCount: Int = 4

    // Export
    @State private var showExport = false
    @State private var exportURL: URL?

    // Selection for dimming + quick-view
    @State private var selectedCategory: String?

    // MARK: - Data windows

    private var breakdowns: [CombinedBreakdown] {
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: max(planCount, 1)
        )
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    private var totals: (income: Decimal, bills: Decimal, remaining: Decimal) {
        let income = breakdowns.reduce(0) { $0 + $1.incomeTotal }
        let carry  = breakdowns.reduce(0) { $0 + $1.carryIn }
        let billsT = breakdowns.reduce(0) { $0 + $1.billsTotal }
        return (income, billsT, income + carry - billsT)
    }

    // Coverage line: date range + period count
    private var coverageText: String? {
        guard let first = breakdowns.first?.period.start,
              let last  = breakdowns.last?.period.end else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let periodsCount = breakdowns.count
        return "\(df.string(from: first)) – \(df.string(from: last)) • \(periodsCount) pay period\(periodsCount == 1 ? "" : "s")"
    }

    // Category slices across the visible window (sorted desc, > 0 only)
    private var categorySlices: [(category: String, amount: Decimal)] {
        let lines = breakdowns.flatMap(\.items)
        let grouped = Dictionary(grouping: lines, by: { ($0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category) })
        return grouped
            .map { (key, vals) in (category: key, amount: vals.reduce(0) { $0 + $1.total }) }
            .sorted { $0.amount > $1.amount }
            .filter { $0.amount > 0 }
    }

    // For quick-view panel
    private var billsByCategory: [String: [AllocatedBillLine]] {
        let all = breakdowns.flatMap(\.items)
        return Dictionary(grouping: all, by: { $0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category })
    }

    // Stable, HIG-safe color mapping (category -> Color)
    private var categoryColorScale: [String: Color] {
        var scale: [String: Color] = [:]
        let palette: [Color] = [
            .blue, .green, .orange, .pink, .purple, .teal, .indigo, .mint, .cyan, .brown, .red, .yellow
        ]
        for cat in categorySlices.map(\.category) {
            let idx = abs(cat.hashValue) % palette.count
            scale[cat] = palette[idx]
        }
        if scale["Uncategorized"] == nil { scale["Uncategorized"] = .gray }
        return scale
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Coverage (header-style, no pill)
                if let cov = coverageText {
                    Section {
                        Text(cov)
                            .font(.subheadline.weight(.semibold)) // smaller than title, header-like
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 2)
                    }
                    .listRowInsets(EdgeInsets())          // remove pill-like horizontal inset look
                    .listRowBackground(Color.clear)       // ensure no colored background behind it
                }

                // MARK: Summary (centered) in Card
                Section {
                    CardContainer {
                        summaryCentered(
                            income: totals.income,
                            bills: totals.bills,
                            remaining: totals.remaining
                        )
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Spending by Category (donut + legend + optional quick view) in Card
                if !categorySlices.isEmpty {
                    Section {
                        CardContainer {
                            VStack(spacing: 12) {
                                donutView
                                categoryList

                                if let cat = selectedCategory,
                                   let lines = billsByCategory[cat],
                                   !lines.isEmpty {
                                    quickViewDetails(category: cat, lines: lines)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                        .animation(.snappy, value: selectedCategory)
                                        .padding(.top, 6)
                                }
                            }
                            .padding(12)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                // MARK: Upcoming Periods in Card (unchanged content)
                Section {
                    CardContainer {
                        VStack(spacing: 0) {
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
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)

                                if b.id != breakdowns.last?.id {
                                    Divider().padding(.leading, 4)
                                }
                            }
                        }
                        .padding(12)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Export Upcoming (CSV)") {
                            exportURL = CSVExporter.upcomingCSV(breakdowns: breakdowns)
                            showExport = true
                        }
                        Divider()
                        Button("Export Income (CSV)") {
                            exportURL = CSVExporter.incomeCSV(incomes: incomeSources())
                            showExport = true
                        }
                        Divider()
                        Button("Export All (CSV)") {
                            exportURL = CSVExporter.allCSV(
                                breakdowns: breakdowns,
                                bills: bills,
                                incomes: incomeSources()
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
            .scrollContentBackground(.hidden) // let material cards contrast against the app bg
            .background(Color.clear)
        }
    }

    // MARK: - Donut (persistent, dims others when selected; no background)

    private var donutView: some View {
        let domain = categorySlices.map(\.category)
        let range  = categorySlices.map { categoryColorScale[$0.category] ?? .accentColor }
        let total  = categorySlices.reduce(Decimal(0)) { $0 + $1.amount }

        return Chart(categorySlices, id: \.category) { item in
            let value = NSDecimalNumber(decimal: item.amount).doubleValue
            SectorMark(
                angle: .value("Amount", value),
                innerRadius: .ratio(0.60)
            )
            .foregroundStyle(by: .value("Category", item.category))
            .opacity(selectedCategory == nil || selectedCategory == item.category ? 1.0 : 0.30)
            .annotation(position: .overlay, alignment: .center) {
                let pct = (total == 0) ? 0 : (item.amount / total * 100)
                if pct >= 7 {
                    Text("\(Int((pct as NSDecimalNumber).doubleValue.rounded()))%")
                        .font(.caption2.weight(.semibold))
                        .shadow(radius: 1)
                }
            }
        }
        .frame(height: 220)
        .chartLegend(.hidden)
        .chartForegroundStyleScale(domain: domain, range: range)
        .accessibilityHidden(true)
    }

    // MARK: - Legend (persistent; dims when not selected)

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(categorySlices, id: \.category) { s in
                Button {
                    withAnimation(.snappy) {
                        selectedCategory = (selectedCategory == s.category) ? nil : s.category
                    }
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(categoryColorScale[s.category] ?? .accentColor)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(.quaternary))

                        Text(s.category)
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        Text(formatCurrency(s.amount))
                            .font(.subheadline).monospacedDigit()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6)
                    .opacity(selectedCategory == nil || selectedCategory == s.category ? 1.0 : 0.45)
                }
                .buttonStyle(.plain)

                if s.category != categorySlices.last?.category {
                    Divider().padding(.leading, 22)
                }
            }
        }
        .accessibilityLabel("Category breakdown list")
    }

    // MARK: - Quick-view details (slide-down inline panel)

    private func quickViewDetails(category: String, lines: [AllocatedBillLine]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(categoryColorScale[category] ?? .accentColor)
                    .frame(width: 8, height: 8)
                Text("Details: \(category)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Close") {
                    withAnimation(.snappy) { selectedCategory = nil }
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.bottom, 2)

            ForEach(lines) { line in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(line.bill.name.isEmpty ? "Untitled Bill" : line.bill.name)
                        Text("\(line.occurrences) × \(formatCurrency(line.amountEach))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatCurrency(line.total)).monospacedDigit()
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - Summary (CENTERED)

    private func summaryCentered(income: Decimal, bills: Decimal, remaining: Decimal) -> some View {
        HStack(spacing: 24) {
            summaryTileCentered(title: "Income", amount: income, emphasize: false)
            summaryTileCentered(title: "Bills", amount: bills, emphasize: false)
            summaryTileCentered(title: "Remaining", amount: remaining, emphasize: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .accessibilityElement(children: .combine)
    }

    private func summaryTileCentered(title: String, amount: Decimal, emphasize: Bool) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formatCurrency(amount))
                .font(.headline.weight(emphasize ? .semibold : .regular))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Utilities

    private func incomeSources() -> [IncomeSource] {
        let set = Set(schedules.compactMap { $0.source })
        return Array(set).sorted { $0.name < $1.name }
    }

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}

// MARK: - Card Container (shared look: blurred, rounded, subtle border + shadow)
private struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}
