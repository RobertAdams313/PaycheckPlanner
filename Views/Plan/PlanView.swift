//
//  PlanView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct PlanView: View {
    @Query(sort: \IncomeSource.startDate) var incomeSources: [IncomeSource]
    @Query(sort: \Bill.dueDate) var bills: [Bill]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Upcoming Paychecks")) {
                    ForEach(incomeSources) { source in
                        let summaries = BudgetEngine.summaries(for: source, bills: bills, count: 6)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(source.name)
                                .font(.headline)
                            ForEach(summaries) { s in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(s.periodStart, style: .date)
                                        Text("–")
                                        Text(s.periodEnd.addingTimeInterval(-1), style: .date)
                                        Spacer()
                                        Text(source.amount, format: .currency(code: "USD"))
                                            .font(.subheadline).bold()
                                    }
                                    HStack {
                                        Text("Used")
                                        Spacer()
                                        Text(s.billsUsed, format: .currency(code: "USD"))
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                    HStack {
                                        Text("Remaining").fontWeight(.semibold)
                                        Spacer()
                                        Text(s.remaining, format: .currency(code: "USD"))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(s.remaining >= 0 ? .green : .red)
                                    }
                                    .font(.footnote)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Bills")) {
                    ForEach(bills) { bill in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(bill.name).font(.headline)
                                Text("Due: \(bill.dueDate, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(bill.amount, format: .currency(code: "USD"))
                        }
                    }
                }
            }
            .navigationTitle("Plan")
        }
    }
}
