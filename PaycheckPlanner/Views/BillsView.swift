//
//  BillsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Bills list + Add (+) button that presents the BillEditor.
/// Also listens to router.showAddBillSheet, so "Get Started" from Plan can open it.
struct BillsView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context

    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    @State private var editingBill: Bill?

    var body: some View {
        NavigationStack {
            List {
                if bills.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Text("No bills yet")
                                .font(.headline)
                            Text("Tap the + button to add your first bill.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                } else {
                    ForEach(bills) { bill in
                        Button {
                            editingBill = bill
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bill.name).font(.body)
                                    Text("\(bill.anchorDueDate, style: .date) • \(bill.recurrence.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(bill.amount))
                                    .font(.headline)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            context.delete(bills[idx])
                        }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Bills")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        router.showAddBillSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // Add new bill sheet
            .sheet(isPresented: $router.showAddBillSheet) {
                BillEditorView(existingBill: nil) { created in
                    // Only close if a bill was actually created
                    if created { router.showAddBillSheet = false }
                }
            }
            // Edit existing bill
            .sheet(item: $editingBill) { bill in
                BillEditorView(existingBill: bill) { _ in
                    editingBill = nil
                }
            }
        }
    }

    private func formatCurrency(_ value: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: value)
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = code
        fmt.maximumFractionDigits = 2
        return fmt.string(from: n) ?? "$0.00"
    }
}
