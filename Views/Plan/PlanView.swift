//
//  PlanView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

//
//  PlanView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - PlanView

struct PlanView: View {
    // Explicit sort descriptor helps SwiftData inference.
    @Query(sort: [SortDescriptor(\Bill.dueDate, order: .forward)]) private var bills: [Bill]
    @Query private var incomeSources: [IncomeSource]

    @State private var selectedSourceIndex: Int = 0
    @State private var periodCount: Int = 6 // 3 or 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // Income source picker by index
                if !incomeSources.isEmpty {
                    Picker("Income", selection: $selectedSourceIndex) {
                        ForEach(incomeSources.indices, id: \.self) { idx in
                            Text(label(for: incomeSources[idx])).tag(idx)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                } else {
                    Text("Add an Income Source to see plan summaries.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // 3 vs 6 periods
                Picker("Periods", selection: $periodCount) {
                    Text("3").tag(3)
                    Text("6").tag(6)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Summaries
                List {
                    if let source = currentSource {
                        let summaries = BudgetEngine.summaries(for: source, bills: bills, count: periodCount)
                        ForEach(Array(summaries.enumerated()), id: \.offset) { _, summary in
                            Section(header: sectionHeader(for: summary.period)) {
                                summaryRow(summary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Helpers

    private var currentSource: IncomeSource? {
        guard incomeSources.indices.contains(selectedSourceIndex) else { return nil }
        return incomeSources[selectedSourceIndex]
    }

    private func label(for source: IncomeSource) -> String {
        // If your model exposes a `name`, prefer it:
        // return source.name
        // Otherwise, keep a safe fallback without removing features.
        let m = Mirror(reflecting: source)
        for child in m.children {
            let key = child.label?.lowercased() ?? ""
            if key == "name" || key == "title" || key.contains("label"),
               let s = child.value as? String, !s.isEmpty { return s }
        }
        return "Income Source"
    }

    private func sectionHeader(for period: DateInterval) -> some View {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return Text("\(df.string(from: period.start)) – \(df.string(from: period.end))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    @ViewBuilder
    private func summaryRow(_ summary: BudgetSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            // These can be Decimal or Double in your models.
            let billsValue: MoneyConvertible = summary.totalBills
            let remainingValue: MoneyConvertible = summary.remaining

            let billsDouble = billsValue.asDouble
            let remainingDouble = remainingValue.asDouble
            let total = billsDouble + remainingDouble
            let percentUsed = total > 0 ? min(max(billsDouble / total, 0), 1) : 0

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Bills:").foregroundStyle(.secondary)
                    Text(billsValue.currencyString())
                    Spacer()
                    Text("Remaining:").foregroundStyle(.secondary)
                    Text(remainingValue.currencyString())
                        .foregroundStyle(remainingDouble >= 0 ? .green : .red)
                }
                .font(.caption)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(.quaternary)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.blue.opacity(0.3))
                            .frame(width: geo.size.width * percentUsed)
                    }
                }
                .frame(height: 10)
            }
            .padding(.vertical, 4)

            if !summary.bills.isEmpty {
                ForEach(Array(summary.bills.enumerated()), id: \.offset) { _, bill in
                    let amountValue: MoneyConvertible = bill.amount
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: bill.name).font(.subheadline)
                            Text(bill.dueDate, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(amountValue.currencyString()).font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            } else {
                Text("No bills in this period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
