//
//  PlanView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25
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

    /// Current + future periods (current is first).
    private var upcomingBreakdowns: [CombinedBreakdown] {
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: max(planCount, 1) + 1,
            from: Date.now,
            using: .current
        )
        return SafeAllocationEngine.allocate(bills: bills, into: periods, calendar: .current)
    }

    /// Number of previous periods available (ended strictly before today).
    private var previousCount: Int {
        let today = Calendar.current.startOfDay(for: Date.now)
        let pastStart = Calendar.current.date(byAdding: .day, value: -180, to: today) ?? today
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: 60,
            from: pastStart,
            using: .current
        )
        let allocated = SafeAllocationEngine.allocate(bills: bills, into: periods, calendar: .current)
        return allocated.filter { $0.period.end <= today }.count
    }

    /// Display string for the badge (cap at 99+)
    private var previousCountDisplay: String {
        previousCount > 99 ? "99+" : "\(previousCount)"
    }

    // MARK: - Body (centered column layout)

    var body: some View {
        NavigationStack {
            Group {
                if schedules.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                } else {
                    ScrollView {
                        VStack(spacing: 16) {

                            // Current
                            if let current = upcomingBreakdowns.first {
                                currentHeader(for: current)
                                NavigationLink {
                                    PaycheckDetailView(breakdown: current)
                                } label: {
                                    periodCard(current, emphasizeCurrent: true)
                                }
                                .buttonStyle(.plain)
                            }

                            // Upcoming
                            let upcoming = Array(upcomingBreakdowns.dropFirst())
                            if !upcoming.isEmpty {
                                sectionTitle("Upcoming")
                                ForEach(upcoming) { b in
                                    NavigationLink {
                                        PaycheckDetailView(breakdown: b)
                                    } label: {
                                        periodCard(b, emphasizeCurrent: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Previous periods entry
                            if previousCount > 0 {
                                NavigationLink {
                                    PreviousPeriodsView()
                                } label: {
                                    previousCard()
                                }
                                .buttonStyle(PressCardStyle())
                                .accessibilityLabel("Show Previous Pay Periods, \(previousCountDisplay)")
                            }
                        }
                        .frame(maxWidth: 700)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Plan")
        }
        // One-time data repair so income sources are linked from schedules.
        .task { await repairIncomeBacklinks() }
        // 🔍 DEBUG PROBE (background)
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
                print("🔧 PlanView probe failed: \(error)")
            }
        }
    }

    // MARK: - Section headers (centered-friendly)

    private func currentHeader(for b: CombinedBreakdown) -> some View {
        VStack(spacing: 2) {
            Text(formatDateRange(start: b.period.start, end: b.period.end))
                .font(.headline)
            Text("Current Pay Period")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Card row

    private func periodCard(_ b: CombinedBreakdown, emphasizeCurrent: Bool) -> some View {
        let carryIn   = b.carryIn
        let income    = b.incomeTotal
        let startBal  = income + carryIn
        let billsSum  = b.billsTotal
        let remaining = startBal - billsSum

        // Build income name list once (works even if model changes types)
        let incomeNames: [String] = b.period.incomes.map { occ in
            let trimmed = occ.source.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Untitled Income" : trimmed
        }

        return VStack(alignment: .leading, spacing: 12) {
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

            // Always show Income Name chips when incomes exist
            if !incomeNames.isEmpty {
                IncomeChipsRow(names: incomeNames)
                    .accessibilityIdentifier("incomeChips_\(b.id.uuidString)")
            }

            if carryIn != 0 {
                carryInBadge(carryIn)
            }

            miniRunningBalance(startBalance: startBal, bills: billsSum, endBalance: remaining)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.separator.opacity(0.15))
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Previous periods card

    private func previousCard() -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                Text("Show Previous Pay Periods")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.tail)

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

                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
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
        let fraction = min(max(spend / max(start, 0.0001), 0), 1)
        let percent = Int((fraction * 100).rounded())

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Bills this period")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text("\(percent)%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            ProgressView(value: fraction)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .accessibilityLabel("Bills this period")
                .accessibilityValue("\(percent) percent of income allocated to bills")

            HStack(spacing: 6) {
                Text(formatCurrency(startBalance))
                Spacer(minLength: 0)
                Text("→").accessibilityHidden(true)
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

    // MARK: - One-time backlink repair

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

// MARK: - Income chips row (names only; no model type dependency)

private struct IncomeChipsRow: View {
    let names: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(names.map(normalized), id: \.self) { title in
                    Chip(title: title)
                }
            }
            .padding(.vertical, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Income sources for this period")
    }

    private func normalized(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Untitled Income" : t
    }
}

private struct Chip: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}
