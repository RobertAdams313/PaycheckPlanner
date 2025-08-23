//
//  BillsListView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  BillsListView.swift
//  PaycheckPlanner
//

import SwiftUI
import SwiftData

struct BillsListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    var body: some View {
        Group {
            if bills.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(bills) { b in
                        NavigationLink {
                            BillEditorView(existingBill: b) { _ in }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.name.isEmpty ? "Untitled" : b.name)
                                        .font(.headline)
                                    Text("\(b.recurrence.uiName) • \(uiMonthDay(b.anchorDueDate))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(b.amount))
                                    .monospacedDigit()
                            }
                            .contentShape(Rectangle())
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(b)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.insetGrouped)
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
                .accessibilityLabel("Add Bill")
            }
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No bills yet")
                .font(.title3).bold()
            Text("Tap the + button to add your first bill.")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                router.showAddBillSheet = true
            } label: {
                Label("Add Bill", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
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
