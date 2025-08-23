//
//  InsightsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Simple insights: totals across the next N periods + a per-period list.
/// Uses CombinedPayEventsEngine.combinedPeriods + SafeAllocationEngine.allocate.
struct InsightsView: View {
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]
    @AppStorage("overviewPeriodCount") private var periodCount: Int = 6

    private var breakdowns: [CombinedBreakdown] {
        let count = (periodCount == 3 || periodCount == 6) ? periodCount : 6
        let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: count)
        return SafeAllocationEngine.allocate(bills: bills, into: periods)
    }

    private var totals: (income: Decimal, bills: Decimal, leftover: Decimal) {
        let income = breakdowns.reduce(0) { $0 + $1.incomeTotal }
        let billsT = breakdowns.reduce(0) { $0 + $1.billsTotal }
        return (income, billsT, income - billsT)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary (next \(breakdowns.count) paychecks)") {
                    HStack { Text("Income"); Spacer(); Text(formatCurrency(totals.income)).bold() }
                    HStack { Text("Bills");  Spacer(); Text(formatCurrency(totals.bills)).bold() }
                    HStack { Text("Leftover"); Spacer(); Text(formatCurrency(totals.leftover)).bold() }
                }

                Section("By Paycheck") {
                    ForEach(breakdowns) { b in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(b.period.payday, format: .dateTime.month().day().year())
                                Text("\(b.period.incomes.count) source\(b.period.incomes.count == 1 ? "" : "s")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Bills \(formatCurrency(b.billsTotal))").font(.caption)
                                Text(formatCurrency(b.incomeTotal - b.billsTotal)).bold()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Insights")
        }
    }

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = code; f.maximumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}
