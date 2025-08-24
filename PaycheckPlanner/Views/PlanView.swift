//
//  PlanView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct PlanView: View {
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    // NEW: how many to show (set in Settings). Default = 4.
    @AppStorage("planPeriodCount") private var planCount: Int = 4

    private var breakdowns: [CombinedBreakdown] {
        let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: max(planCount, 1))
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    var body: some View {
        NavigationStack {
            Group {
                if schedules.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("Plan")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Let’s plan your first paycheck")
                .font(.title3).bold()
            Text("Add at least one bill to get started. We’ll show how each paycheck is used.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                router.tab = .bills
                router.showAddBillSheet = true
            } label: {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var listContent: some View {
        List {
            ForEach(breakdowns) { b in
                NavigationLink { PaycheckDetailView(breakdown: b) } label: { row(for: b) }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemGroupedBackground))
    }

    private func row(for b: CombinedBreakdown) -> some View {
        let income = b.incomeTotal
        let billsTotal  = b.billsTotal
        let leftover = income - billsTotal
        let fraction = clampedFraction(numerator: billsTotal, denominator: max(income, 0.01))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(b.period.payday, format: .dateTime.month().day().year()).font(.headline)
                Spacer()
                Text(formatCurrency(income)).font(.headline)
            }

            ProgressView(value: fraction)
                .tint(.accentColor)

            HStack(spacing: 12) {
                labelValue("Bills", formatCurrency(billsTotal))
                Divider().frame(height: 12)
                labelValue("Leftover", formatCurrency(leftover))

                Spacer()
                // Quick hint: how many bills are due in this window
                if !b.items.isEmpty {
                    Text("\(b.items.count) bill\(b.items.count == 1 ? "" : "s")")
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
        HStack(spacing: 4) { Text(label).foregroundStyle(.secondary); Text(value).bold() }
    }
    private func clampedFraction(numerator: Decimal, denominator: Decimal) -> Double {
        let num = NSDecimalNumber(decimal: numerator).doubleValue
        let den = max(NSDecimalNumber(decimal: denominator).doubleValue, 0.0001)
        return min(max(num / den, 0), 1)
    }
    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code; f.maximumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}
