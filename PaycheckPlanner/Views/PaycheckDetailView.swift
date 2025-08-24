//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Shows full details for a single combined period: incomes, bills, and leftover.
/// No references to `PaycheckBreakdown` — uses `CombinedBreakdown` directly.
struct PaycheckDetailView: View {
    let breakdown: CombinedBreakdown

    var body: some View {
        List {
            headerCard

            if !breakdown.period.incomes.isEmpty {
                Section("Income Sources") {
                    ForEach(breakdown.period.incomes) { inc in
                        HStack {
                            Text(inc.source.name)
                            Spacer()
                            Text(formatCurrency(inc.amount))
                                .font(.headline)
                        }
                    }
                }
            }

            Section("Bills in this pay period") {
                if breakdown.items.isEmpty {
                    Text("No bills due in this window.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(breakdown.items) { line in
                        billRow(line)
                    }
                    totalsRow
                }
            }
        }
        .navigationTitle(breakdown.period.payday.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var headerCard: some View {
        let income = breakdown.incomeTotal
        let bills  = breakdown.billsTotal
        let leftover = income - bills
        let fraction = clampedFraction(numerator: bills, denominator: max(income, 0.01))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payday")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(breakdown.period.payday, format: .dateTime.month().day().year())
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(income))
                        .font(.headline)
                }
            }

            ProgressView(value: fraction) {
                Text("Income used")
            } currentValueLabel: {
                Text("\(Int(fraction * 100))%")
            }
            .tint(.accentColor)

            HStack {
                labelValue("Bills", formatCurrency(bills))
                Spacer(minLength: 16)
                labelValue("Leftover", formatCurrency(leftover))
            }
            .font(.caption)
        }
        .padding(.vertical, 8)
    }

    private func billRow(_ line: AllocatedBillLine) -> some View {
        let each = line.amountEach
        let total = line.total
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.bill.name)
                Text(line.bill.anchorDueDate, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if line.occurrences > 1 {
                    Text("\(line.occurrences) occurrences in window")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(total)).font(.headline)
                if line.occurrences > 1 {
                    Text("(\(line.occurrences) × \(formatCurrency(each)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var totalsRow: some View {
        HStack {
            Text("Total Bills").bold()
            Spacer()
            Text(formatCurrency(breakdown.billsTotal)).bold()
        }
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
