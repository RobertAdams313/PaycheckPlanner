//
//  PreviousPeriodsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//

import SwiftUI
import SwiftData

struct PreviousPeriodsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \IncomeSchedule.anchorDate, order: .forward)
    private var schedules: [IncomeSchedule]

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    // Page size for incremental loading
    @State private var showCount: Int = 12

    private var previousBreakdownsAll: [CombinedBreakdown] {
        // Generate a wide range in the past, then filter to periods that ended before today
        let today = Calendar.current.startOfDay(for: Date.now)
        let pastStart = Calendar.current.date(byAdding: .day, value: -365, to: today) ?? today

        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: 180,           // large grid to cover past year across frequencies
            from: pastStart
        )
        let allocated = SafeAllocationEngine.allocate(bills: bills, into: periods)

        // Only those that ended strictly before today; most recent first
        return allocated
            .filter { $0.period.end <= today }
            .sorted { $0.period.end > $1.period.end }
    }

    private var previousBreakdownsPaged: [CombinedBreakdown] {
        Array(previousBreakdownsAll.prefix(showCount))
    }

    var body: some View {
        Group {
            if schedules.isEmpty {
                emptyState
            } else if previousBreakdownsAll.isEmpty {
                noHistoryState
            } else {
                ScrollView {
                    VStack(spacing: 16) {

                        // Header
                        header

                        // Cards
                        ForEach(previousBreakdownsPaged) { b in
                            NavigationLink {
                                PaycheckDetailView(breakdown: b)
                            } label: {
                                periodCard(b)
                            }
                            .buttonStyle(.plain)
                        }

                        // Load More
                        if showCount < previousBreakdownsAll.count {
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showCount = min(previousBreakdownsAll.count, showCount + 12)
                                }
                            } label: {
                                loadMoreCard(remaining: previousBreakdownsAll.count - showCount)
                            }
                            .buttonStyle(PressCardStyle())
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: 700) // match PlanView column, adjust to taste
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Previous Periods")
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            Text("History")
                .font(.headline)
            if let firstEnd = previousBreakdownsPaged.first?.period.end,
               let lastEnd  = previousBreakdownsPaged.last?.period.end {
                Text("\(formatMonthYear(lastEnd)) – \(formatMonthYear(firstEnd))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cards

    private func periodCard(_ b: CombinedBreakdown) -> some View {
        let carryIn   = b.carryIn
        let income    = b.incomeTotal
        let startBal  = income + carryIn
        let billsSum  = b.billsTotal
        let remaining = startBal - billsSum

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

    private func loadMoreCard(remaining: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Text("Load More")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(remaining)")
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

    // MARK: - Badges / Bars

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

    private func miniRunningBalance(startBalance: Decimal, bills: Decimal, endBalance: Decimal) -> some View {
        let start = max(0, (startBalance as NSDecimalNumber).doubleValue)
        let spend = max(0, (bills as NSDecimalNumber).doubleValue)
        let fraction = min(max(spend / max(start, 0.0001), 0), 1) // 0...1
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

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No schedules yet")
                .font(.title3).bold()
            Text("Add at least one income schedule and bill to build your pay period history.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var noHistoryState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No previous periods yet")
                .font(.title3).bold()
            Text("Once a pay period completes, you’ll see the history here.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Formatting

    private func formatMonthYear(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return df.string(from: d)
    }

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
}

// MARK: - Pressed effect (same as PlanView)

private struct PressCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
    }
}

private extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = fmt
        return df
    }
}
