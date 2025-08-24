//
//  BillsListView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct BillsListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    @State private var editing: Bill?

    var body: some View {
        NavigationStack {
            List {
                if bills.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Text("No bills yet").font(.headline)
                            Text("Tap + to add your first bill.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                } else {
                    ForEach(bills) { bill in
                        Button { editing = bill } label: { row(for: bill) }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(bills[i]) }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Bills")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { router.showAddBillSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // ✅ Present Add Bill when router flag is set (from PlanView “Get Started”).
            .sheet(isPresented: $router.showAddBillSheet) {
                AddOrEditBillView(existingBill: nil) { _ in
                    router.showAddBillSheet = false
                }
            }
            .sheet(item: $editing) { bill in
                AddOrEditBillView(existingBill: bill) { _ in editing = nil }
            }
        }
    }

    private func row(for bill: Bill) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                Text("\(recurrenceText(bill.recurrence)) • \(bill.anchorDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCurrency(bill.amount)).font(.headline)
        }
        .padding(.vertical, 2)
    }

    private func recurrenceText(_ r: BillRecurrence) -> String {
        switch r {
        case .once:        return "One time"
        case .weekly:      return "Weekly"
        case .biweekly:    return "Every 2 Weeks"
        case .semimonthly: return "Semi-monthly"
        case .monthly:     return "Monthly"
        }
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
