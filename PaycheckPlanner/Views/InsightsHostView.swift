//
//  InsightsHostView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/3/25 – Async snapshot (SwiftData-safe), always-visible summary,
//                      CardKit integration, compiler-friendly structure + iOS17-safe onChange.
//
import SwiftUI
import SwiftData
import Charts

struct InsightsHostView: View {
    // Data
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    // Settings
    @AppStorage("planPeriodCount") private var planCount: Int = 4

    // Export
    @State private var showExport = false
    @State private var exportURL: URL?

    // Selection for dimming + quick-view
    @State private var selectedCategory: String?

    // Snapshots (computed safely on main actor, with yields)
    @State private var breakdownsSnap: [CombinedBreakdown] = []
    @State private var totalsSnap: (income: Decimal, bills: Decimal, remaining: Decimal) = (0, 0, 0)

    // Loading/empty state
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                coverageSection()
                summarySection()
                categorySection()
                periodsSection()
            }
            .navigationTitle("Insights")
            .toolbar { exportToolbar() }
            .sheet(isPresented: $showExport) { exportSheet() }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .task { await recomputeSnapshots() }
            // iOS 17-safe change handlers
            .onChangeValueCompat(planCount) { _, _ in
                Task { await recomputeSnapshots() }
            }
            .onChangeValueCompat(schedules.count) { _, _ in
                Task { await recomputeSnapshots() }
            }
            .onChangeValueCompat(bills.count) { _, _ in
                Task { await recomputeSnapshots() }
            }
        }
    }

    // MARK: - Async compute (SwiftData-safe; yields between steps)

    private func recomputeSnapshots() async {
        await MainActor.run { isLoading = true }

        // Capture current values (SwiftData access on main actor)
        let s = schedules
        let bs = bills
        let count = max(planCount, 1)

        // Yield to avoid blocking first frame
        await Task.yield()

        // Step 1: Build periods
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: s,
            count: count
        )

        await Task.yield()

        // Step 2: Allocate bills into periods
        let computed = SafeAllocationEngine.allocate(
            bills: bs,
            into: periods
        )

        // Step 3: Totals
        let income = computed.reduce(0) { $0 + $1.incomeTotal }
        let carry  = computed.reduce(0) { $0 + $1.carryIn }
        let billsT = computed.reduce(0) { $0 + $1.billsTotal }
        let totals = (income, billsT, income + carry - billsT)

        // Publish
        await MainActor.run {
            self.breakdownsSnap = computed
            self.totalsSnap = totals
            self.selectedCategory = nil
            self.isLoading = false
        }
    }

    // MARK: - Derived data (from snapshots)

    private var coverageText: String? {
        guard let first = breakdownsSnap.first?.period.start,
              let last  = breakdownsSnap.last?.period.end else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        let periodsCount = breakdownsSnap.count
        return "\(df.string(from: first)) – \(df.string(from: last)) • \(periodsCount) pay period\(periodsCount == 1 ? "" : "s")"
    }

    // Category slices across the visible window (sorted desc, > 0 only)
    private var categorySlices: [(category: String, amount: Decimal)] {
        let lines = breakdownsSnap.flatMap(\.items)
        let grouped = Dictionary(grouping: lines, by: { ($0.bill.category.isEmpty ? "Uncategorized" : $0.bill.category) })
        return grouped
            .map { (key, vals) in (category: key, amount: vals.reduce(0) { $0 + $1.total }) }
            .sorted { $0.amount > $1.amount }
            .filter { $0.amount > 0 }
    }

    // For quick-view panel
    private var billsByCategory: [String: [AllocatedBillLine]] {
        let all = breakdownsSnap.flatMap(\.items)
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

    // MARK: - Sections

    @ViewBuilder
    private func coverageSection() -> some View {
        if let cov = coverageText, !isLoading {
            Section {
                Text(cov)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func summarySection() -> some View {
        Section {
            CardContainer {
                ZStack(alignment: .center) {
                    if isLoading {
                        HStack(spacing: 24) {
                            skeletonTile(title: "Income")
                            skeletonTile(title: "Bills")
                            skeletonTile(title: "Remaining")
                        }
                        .accessibilityHidden(true)
                    }
                    summaryCentered(
                        income: totalsSnap.income,
                        bills: totalsSnap.bills,
                        remaining: totalsSnap.remaining
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
        }
        .cardListRowInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
    }

    @ViewBuilder
    private func categorySection() -> some View {
        if !isLoading && !categorySlices.isEmpty {
            Section {
                CardContainer {
                    VStack(spacing: 12) {
                        donutView()
                        categoryListView()

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
            .cardListRowInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
        }
    }

    @ViewBuilder
    private func periodsSection() -> some View {
        Section {
            CardContainer {
                if isLoading {
                    VStack(alignment: .leading, spacing: 8) {
                        skeletonLine()
                        skeletonLine()
                        skeletonLine()
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 0) {
                        ForEach(breakdownsSnap) { b in
                            NavigationLink {
                                PaycheckDetailView(breakdown: b)
                            } label: {
                                periodRow(b)
                            }
                            .buttonStyle(.plain)

                            if b.id != breakdownsSnap.last?.id {
                                Divider().padding(.leading, 4)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .cardListRowInsets(top: 4, leading: 16, bottom: 12, trailing: 16)
    }

    // MARK: - Row builders

    @ViewBuilder
    private func periodRow(_ b: CombinedBreakdown) -> some View {
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

    // MARK: - Donut + Legend

    private func donutView() -> some View {
        let domain: [String] = categorySlices.map(\.category)
        let range: [Color]  = categorySlices.map { categoryColorScale[$0.category] ?? .accentColor }
        let total: Decimal  = categorySlices.reduce(Decimal(0)) { $0 + $1.amount }

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

    private func categoryListView() -> some View {
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

    // MARK: - Quick-view details

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

    // MARK: - Toolbar & Sheets

    @ToolbarContentBuilder
    private func exportToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Export Upcoming (CSV)") {
                    exportURL = CSVExporter.upcomingCSV(breakdowns: breakdownsSnap)
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
                        breakdowns: breakdownsSnap,
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

    @ViewBuilder
    private func exportSheet() -> some View {
        if let url = exportURL {
            ShareSheet(activityItems: [url])
        }
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

    // MARK: - Skeletons

    private func skeletonTile(title: String) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 4)
                .fill(.quaternary)
                .frame(width: 84, height: 16)
        }
        .frame(maxWidth: .infinity)
        .redacted(reason: .placeholder)
    }

    private func skeletonLine() -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.quaternary)
            .frame(height: 16)
            .redacted(reason: .placeholder)
    }
}

// MARK: - iOS 17 onChange compatibility for plain values (Equatable)

private struct OnChangeValueCompatModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let action: (_ old: Value, _ new: Value) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            // iOS 16: single-parameter version; we don’t have `oldValue`.
            content.onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}

private extension View {
    /// Use this when you want iOS-17-safe `.onChange` for a plain Equatable value (not a Binding).
    func onChangeValueCompat<Value: Equatable>(
        _ value: Value,
        perform: @escaping (_ old: Value, _ new: Value) -> Void
    ) -> some View {
        modifier(OnChangeValueCompatModifier(value: value, action: perform))
    }
}
