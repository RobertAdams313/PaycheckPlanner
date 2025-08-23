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

import SwiftUI
import SwiftData

struct PlanView: View {
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

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
                    List(breakdowns) { b in
                        NavigationLink {
                            PaycheckDetailView(breakdown: b)
                        } label: {
                            row(for: b)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Plan")
        }
    }

    // MARK: - Row

    private func row(for b: CombinedBreakdown) -> some View {
        let carryIn   = b.carryIn
        let thisCheck = b.incomeTotal
        let startBal  = thisCheck + carryIn
        let remaining = b.leftover
        let bills     = b.billsTotal

        return VStack(alignment: .leading, spacing: 8) {
            // Top line: date range
            Text(uiDateIntervalString(b.period.start, b.period.end))
                .font(.headline)

            // NEW: chips that explicitly call out sources of funds
            HStack(spacing: 8) {
                if carryIn != 0 {
                    pill(label: "Carry-in", amount: carryIn, systemImage: (carryIn as NSDecimalNumber).doubleValue >= 0 ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill")
                }
                pill(label: "This check", amount: thisCheck, systemImage: "banknote.fill")
            }

            // Subtitle: Income • Bills
            Text("Income \(formatCurrency(thisCheck)) • Bills \(formatCurrency(bills))")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Mini running-balance preview (unchanged)
            miniRunningBalance(startBalance: startBal, bills: bills, endBalance: remaining)

            // Trailing Remaining
            HStack {
                Spacer()
                Text(formatCurrency(remaining))
                    .monospacedDigit()
                    .accessibilityLabel("Remaining")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Small pill helper

    private func pill(label: String, amount: Decimal, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).imageScale(.small)
            Text(label).font(.caption2)
            Text(formatCurrency(amount)).font(.caption2).bold()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
        .overlay { Capsule().strokeBorder(.quaternary, lineWidth: 0.5) }
        .accessibilityLabel("\(label) \(formatCurrency(amount))")
    }

    // MARK: - Mini running-balance preview

    private func miniRunningBalance(startBalance: Decimal, bills: Decimal, endBalance: Decimal) -> some View {
        let start = max(0, (startBalance as NSDecimalNumber).doubleValue)
        let spend = max(0, (bills as NSDecimalNumber).doubleValue)
        let total = max(start, 0.0001)
        let frac = min(max(1.0 - (spend / total), 0), 1) // portion remaining

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .frame(height: 6)
                        .foregroundStyle(.quaternary)
                    RoundedRectangle(cornerRadius: 3)
                        .frame(width: geo.size.width * CGFloat(frac), height: 6)
                        .foregroundStyle(.tint)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(formatCurrency(startBalance))")
                Spacer()
                Text("→")
                Spacer()
                Text("\(formatCurrency(endBalance))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Running balance from \(formatCurrency(startBalance)) to \(formatCurrency(endBalance))")
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
            Text("Add at least one bill to get started. We’ll show how each upcoming paycheck lines up with your bills.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button {
                router.showAddBillSheet = true
            } label: {
                Label("Add your first bill", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Utilities

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code; f.maximumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}
