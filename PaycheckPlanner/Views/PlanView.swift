//
//  PlanView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

//
//  PlanView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/1/25
//

import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter

    @Query(sort: \IncomeSchedule.anchorDate, order: .forward)
    private var schedules: [IncomeSchedule]

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    /// How many future periods to show (after the current one)
    @AppStorage("planPeriodCount") private var planCount: Int = 4

    // MARK: - Period sources

    /// Current + future periods (current is first). The new engine guarantees the first
    /// period spans “today” when there’s a single recurring schedule (weekly/biweekly/monthly/semimonthly).
    private var upcomingBreakdowns: [CombinedBreakdown] {
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: max(planCount, 1) + 1 // current + N upcoming
        )
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    /// Number of previous periods available (ended strictly before today).
    private var previousCount: Int {
        let today = Calendar.current.startOfDay(for: Date.now)
        let pastStart = Calendar.current.date(byAdding: .day, value: -180, to: today) ?? today
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: 60,
            from: pastStart
        )
        let allocated = SafeAllocationEngine.allocate(bills: bills, into: periods)
        return allocated.filter { $0.period.end <= today }.count
    }

    /// Display string for the badge (cap at 99+)
    private var previousCountDisplay: String {
        previousCount > 99 ? "99+" : "\(previousCount)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if schedules.isEmpty {
                    emptyState
                } else {
                    List {
                        if let current = upcomingBreakdowns.first {
                            Section {
                                NavigationLink {
                                    PaycheckDetailView(breakdown: current)
                                } label: {
                                    periodCard(current, emphasizeCurrent: true)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            } header: {
                                // HIG polish: date range first, “Current Pay Period” under it
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDateRange(start: current.period.start, end: current.period.end))
                                        .font(.headline)
                                    Text("Current Pay Period")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .textCase(nil)
                            }
                        }

                        let upcoming = Array(upcomingBreakdowns.dropFirst())
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { b in
                                    NavigationLink {
                                        PaycheckDetailView(breakdown: b)
                                    } label: {
                                        periodCard(b, emphasizeCurrent: false)
                                    }
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }

                        // Link to history only if we have previous periods
                        if previousCount > 0 {
                            Section {
                                NavigationLink {
                                    PreviousPeriodsView()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("See Previous Pay Periods")

                                        // Badge capsule with capped count (Apple-like)
                                        Text(previousCountDisplay)
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(.thinMaterial)
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(.quaternary, lineWidth: 0.5)
                                            )
                                            .accessibilityHidden(true)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 6)
                                    .accessibilityLabel("See Previous Pay Periods, \(previousCountDisplay)")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Plan")
        }
        // One-time data repair so income sources are linked from schedules.
        .task {
            await repairIncomeBacklinks()
        }
        // 🔍 DEBUG PROBE (background): print schedules and computed periods/incomes to Xcode console
        .task {
            do {
                try await context.background { bg in
                    let cal = Calendar.current
                    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"

                    let schedules = try bg.fetch(FetchDescriptor<IncomeSchedule>())

                    print("🧭 Schedules in store: \(schedules.count)")
                    for s in schedules {
                        let srcName = (s.source?.name.isEmpty == false) ? s.source!.name : "Unnamed"
                        print(" – \(srcName) | \(s.frequency) @ \(f.string(from: s.anchorDate)) | semi \(s.semimonthlyFirstDay)/\(s.semimonthlySecondDay)")

                        // Single-schedule probe
                        let probe = CombinedPayEventsEngine.combinedPeriods(
                            schedules: [s],
                            count: 2,
                            from: Date.now,
                            using: cal
                        )
                        if let p = probe.first {
                            print("    grid: \(f.string(from: p.start)) → \(f.string(from: p.end)) (payday \(f.string(from: p.payday)))")
                        }
                    }

                    let periods = CombinedPayEventsEngine.combinedPeriods(
                        schedules: schedules,
                        count: 6,
                        from: Date.now,
                        using: cal
                    )

                    print("🔎 Period probe (combined): \(periods.count) periods")
                    for p in periods {
                        let inc = p.incomes
                            .map { "\($0.source.name.isEmpty ? "Untitled" : $0.source.name): \(NSDecimalNumber(decimal: $0.amount))" }
                            .joined(separator: ", ")
                        print(" • \(f.string(from: p.start)) → \(f.string(from: p.end)) (payday \(f.string(from: p.payday))) | incomes: [\(inc)]  total=\(NSDecimalNumber(decimal: p.incomeTotal))")
                    }
                }
            } catch {
                // Don’t crash the UI; just log the probe error.
                print("🔧 PlanView probe failed: \(error)")
            }
        }
    }

    // MARK: - Card row

    private func periodCard(_ b: CombinedBreakdown, emphasizeCurrent: Bool) -> some View {
        let carryIn   = b.carryIn
        let income    = b.incomeTotal
        let startBal  = income + carryIn
        let billsSum  = b.billsTotal
        let remaining = startBal - billsSum

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatDateRange(start: b.period.start, end: b.period.end))
                        .font(.headline)
                    Text("Income \(formatCurrency(income))  •  Bills \(formatCurrency(billsSum))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Text(formatCurrency(remaining))
                    .bold()
                    .monospacedDigit()
            }

            if carryIn != 0 {
                carryInBadge(carryIn)
            }

            miniRunningBalance(startBalance: startBal, bills: billsSum, endBalance: remaining)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.background.opacity(0.8))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Carry-in badge

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

    // MARK: - Running balance bar

    private func miniRunningBalance(startBalance: Decimal, bills: Decimal, endBalance: Decimal) -> some View {
        let start = max(0, (startBalance as NSDecimalNumber).doubleValue)
        let spend = max(0, (bills as NSDecimalNumber).doubleValue)
        let total = max(start, 0.0001)
        let billsFrac = min(max(spend / total, 0), 1)

        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .frame(height: 6)
                        .foregroundStyle(Color.primary.opacity(0.9))   // “Remaining” rail
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: geo.size.width * CGFloat(billsFrac), height: 6)
                        .foregroundStyle(.tint)                        // Bills filling up
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                Text(formatCurrency(startBalance))
                Spacer(minLength: 0)
                Text("→")
                Spacer(minLength: 0)
                Text(formatCurrency(endBalance))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Let’s plan your first paycheck")
                .font(.title3).bold()
            Text("Add at least one income schedule and bill. We’ll align each upcoming paycheck with your bills.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button {
                router.showAddBillSheet = true
            } label: {
                Label("Add your first bill", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Utilities

    /// Formats a period date range concisely:
    /// - Same month/year:   "Sep 1–15, 2025"
    /// - Same year:         "Sep 29–Oct 13, 2025"
    /// - Different years:   "Dec 30, 2025–Jan 12, 2026"
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

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }

    // MARK: - One-time backlink repair (kept local to avoid extra files)

    private func repairIncomeBacklinks() async {
        do {
            let srcs = try context.fetch(FetchDescriptor<IncomeSource>())
            var changed = false

            for src in srcs {
                if let sched = src.schedule, sched.source == nil {
                    sched.source = src
                    changed = true
                }
            }
            if changed {
                try context.save()
            }
        } catch {
            // non-fatal
            print("Backlink repair failed: \(error)")
        }
    }
}

private extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = fmt
        return df
    }
}
