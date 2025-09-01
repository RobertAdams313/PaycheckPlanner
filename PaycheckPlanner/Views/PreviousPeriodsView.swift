//
//  PreviousPeriodsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  PreviousPeriodsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct PreviousPeriodsView: View {
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward)
    private var schedules: [IncomeSchedule]

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    // MARK: - Data

    /// Previous periods = those that ended strictly before today; newest first.
    private var previousBreakdowns: [CombinedBreakdown] {
        let pastStart = Calendar.current.date(byAdding: .day, value: -180, to: Date())
            ?? Date().addingTimeInterval(-180 * 86400)
        let periods = CombinedPayEventsEngine.combinedPeriods(
            schedules: schedules,
            count: 60,
            from: pastStart
        )
        let allocated = SafeAllocationEngine.allocate(bills: bills, into: periods)
        let today = Calendar.current.startOfDay(for: Date())
        return allocated
            .filter { $0.period.end <= today }
            .sorted { $0.period.end > $1.period.end }
    }

    private var previousCount: Int { previousBreakdowns.count }
    private var previousCountDisplay: String {
        previousCount > 99 ? "99+" : "\(previousCount)"
    }

    // MARK: - Body

    var body: some View {
        List {
            if previousBreakdowns.isEmpty {
                ContentUnavailableView(
                    "No previous periods yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Once a pay period ends, it will appear here.")
                )
            } else {
                ForEach(previousBreakdowns) { b in
                    NavigationLink {
                        PaycheckDetailView(breakdown: b)
                    } label: {
                        periodCard(b)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(
            previousCount > 0
            ? "Previous Periods (\(previousCountDisplay))"
            : "Previous Periods"
        )
    }

    // MARK: - Row

    private func periodCard(_ b: CombinedBreakdown) -> some View {
        let income    = b.incomeTotal
        let startBal  = income + b.carryIn
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

    // MARK: - Helpers (match PlanView style)

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
                        .foregroundStyle(Color.primary.opacity(0.9))
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: geo.size.width * CGFloat(billsFrac), height: 6)
                        .foregroundStyle(.tint)
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

    /// Formats:
    /// - Same month/year:   "Sep 1–15, 2025"
    /// - Same year:         "Sep 29–Oct 13, 2025"
    /// - Different years:   "Dec 30, 2025–Jan 12, 2026"
    private func formatDateRange(start: Date, end: Date) -> String {
        let cal = Calendar.current
        let sComp = cal.dateComponents([.year, .month, .day], from: start)
        let eComp = cal.dateComponents([.year, .month, .day], from: end)

        let dfDay = DateFormatter(); dfDay.dateFormat = "d"
        let dfMonthDay = DateFormatter(); dfMonthDay.dateFormat = "MMM d"
        let dfMonthDayYear = DateFormatter(); dfMonthDayYear.dateFormat = "MMM d, yyyy"

        if sComp.year != eComp.year {
            return "\(dfMonthDayYear.string(from: start))–\(dfMonthDayYear.string(from: end))"
        }
        if sComp.month == eComp.month {
            let month = DateFormatter.cached("MMM").string(from: start)
            return "\(month) \(dfDay.string(from: start))–\(dfDay.string(from: end)), \(sComp.year!)"
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
        return f.string(from: n) ?? "$0.00"
    }
}

private extension DateFormatter {
    static func cached(_ fmt: String) -> DateFormatter {
        let df = DateFormatter()
        df.dateFormat = fmt
        return df
    }
}
