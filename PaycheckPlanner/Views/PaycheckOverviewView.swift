//
//  PaycheckOverviewView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Shows the next N combined pay periods and a quick summary.
/// Tapping a row pushes PaycheckDetailView for that period.
struct PaycheckOverviewView: View {
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    /// Allow user to pick 3 or 6 periods; defaults to 6.
    @AppStorage("overviewPeriodCount") private var periodCount: Int = 6

    // Derived: build periods & allocations on the fly (cheap & pure)
    private var breakdowns: [CombinedBreakdown] {
        let count = (periodCount == 3 || periodCount == 6) ? periodCount : 6
        let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: count)
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    var body: some View {
        NavigationStack {
            Group {
                if schedules.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Upcoming Paychecks")
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No pay schedules yet").font(.title3).bold()
            Text("Add at least one income and its pay schedule to see upcoming paychecks.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var content: some View {
        VStack(spacing: 8) {
            // 3 / 6 toggle
            Picker("Count", selection: $periodCount) {
                Text("3").tag(3)
                Text("6").tag(6)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                ForEach(breakdowns) { b in
                    NavigationLink {
                        PaycheckDetailView(breakdown: b)
                    } label: {
                        row(for: b)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func row(for b: CombinedBreakdown) -> some View {
        let income = b.incomeTotal
        let bills  = b.billsTotal
        let leftover = income - bills
        let fraction = clampedFraction(numerator: bills, denominator: max(income, 0.01))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(b.period.payday, format: .dateTime.month().day().year())
                    .font(.headline)
                Spacer()
                Text(formatCurrency(income)).font(.headline)
            }

            // progress of income used by bills
            ProgressView(value: fraction)
                .tint(.accentColor)

            HStack(spacing: 12) {
                labelValue("Bills", formatCurrency(bills))
                Divider().frame(height: 12)
                labelValue("Leftover", formatCurrency(leftover))
                Spacer()
                if !b.period.incomes.isEmpty {
                    // show how many incomes contribute to this combined period
                    Text("\(b.period.incomes.count) sources")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func labelValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value).bold()
        }
    }

    private func clampedFraction(numerator: Decimal, denominator: Decimal) -> Double {
        let num = NSDecimalNumber(decimal: numerator).doubleValue
        let den = max(NSDecimalNumber(decimal: denominator).doubleValue, 0.0001)
        return min(max(num / den, 0), 1)
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
