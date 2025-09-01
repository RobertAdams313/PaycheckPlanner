//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

/// Shows full details for a single combined period: incomes, bills, and remaining.
struct PaycheckDetailView: View {
    let breakdown: CombinedBreakdown

    var body: some View {
        List {
            // Summary with vertical label-over-value (requested)
            Section {
                summaryGrid
            }

            Section {
                ForEach(breakdown.period.incomes) { inc in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(inc.source.name.isEmpty ? "Untitled income" : inc.source.name)
                            Text(incomeSubtitle(for: inc))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatCurrency(inc.amount))
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Incomes")
            }

            Section {
                ForEach(breakdown.items) { line in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.bill.name)
                            Text(line.bill.category.isEmpty ? "Uncategorized" : line.bill.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if line.occurrences > 1 {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(line.occurrences)× \(formatCurrency(line.amountEach))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatCurrency(line.total)).monospacedDigit().bold()
                            }
                        } else {
                            Text(formatCurrency(line.total))
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                Text("Bills")
            } footer: {
                runningBalanceFooter
            }

            Section {
                HStack {
                    Text("Remaining").bold()
                    Spacer()
                    Text(formatCurrency(breakdown.leftover))
                        .monospacedDigit()
                }
            }
        }
        .navigationTitle(breakdown.period.payday.formatted(.dateTime.month().day().year()))
    }

    // MARK: - Summary

    private var summaryGrid: some View {
        // Three equal columns with label on top
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Income").font(.caption).foregroundStyle(.secondary)
                Text(formatCurrency(breakdown.incomeTotal)).bold()
            }
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bills").font(.caption).foregroundStyle(.secondary)
                Text(formatCurrency(breakdown.billsTotal)).bold()
            }
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text("Remaining").font(.caption).foregroundStyle(.secondary)
                Text(formatCurrency(breakdown.leftover)).bold()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Running Balance Footer

    private var runningBalanceFooter: some View {
        let start = breakdown.incomeTotal + breakdown.carryIn
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Start (Income + Carry-in)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(start)).monospacedDigit()
            }
            HStack {
                Text("Bills")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(breakdown.billsTotal)).monospacedDigit()
            }
            Divider()
            HStack {
                Text("Remaining")
                    .fontWeight(.semibold)
                Spacer()
                Text(formatCurrency(breakdown.leftover))
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
        }
        .font(.caption)
    }

    private func incomeSubtitle(for inc: PeriodIncome) -> String {
        inc.source.schedule?.frequency.displayName ?? "—"
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
