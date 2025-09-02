//
//  BillsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  BillsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25
//

import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var context

    // All bills sorted by anchor due date ascending
    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    // UI State
    @State private var showNewBill = false
    @State private var editingBill: Bill?
    @State private var grouping: Grouping = .dueDate  // default per your request
    @State private var lastError: String?

    enum Grouping: String, CaseIterable, Identifiable {
        case dueDate = "Due Date"
        case category = "Category"
        var id: String { rawValue }
    }

    var body: some View {
        List {
            // Toggle between "Due Date" and "Category" organization
            Section {
                Picker("Grouping", selection: $grouping) {
                    ForEach(Grouping.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("BillsGroupingPicker")
            }

            if bills.isEmpty {
                ContentUnavailableView(
                    "No Bills Yet",
                    systemImage: "list.bullet.rectangle.portrait",
                    description: Text("Add your first bill to start planning.")
                )
            } else {
                switch grouping {
                case .dueDate:
                    dueDateSections
                case .category:
                    categorySections
                }
            }

            if let lastError {
                Section {
                    Text(lastError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewBill = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Bill")
            }
        }
        .sheet(isPresented: $showNewBill) {
            NavigationStack {
                BillEditorView { _ in
                    showNewBill = false
                }
            }
        }
        .sheet(item: $editingBill, onDismiss: { editingBill = nil }) { bill in
            NavigationStack {
                BillEditorView(existingBill: bill) { _ in
                    editingBill = nil
                }
            }
        }
    }

    // MARK: - Views: Due Date Grouping

    private var dueDateSections: some View {
        // Buckets: Overdue (< today), Due Soon (today..+7d), Later (> +7d)
        let today = Calendar.current.startOfDay(for: Date())
        let soonCutoff = Calendar.current.date(byAdding: .day, value: 7, to: today)!

        let overdue   = bills.filter { $0.anchorDueDate < today }
        let dueSoon   = bills.filter { $0.anchorDueDate >= today && $0.anchorDueDate <= soonCutoff }
        let later     = bills.filter { $0.anchorDueDate > soonCutoff }

        return Group {
            if !overdue.isEmpty {
                Section("Overdue") {
                    ForEach(overdue) { bill in
                        billRow(bill)
                    }
                    .onDelete { idx in delete(at: idx, from: overdue) }
                }
            }
            if !dueSoon.isEmpty {
                Section("Due Soon") {
                    ForEach(dueSoon) { bill in
                        billRow(bill)
                    }
                    .onDelete { idx in delete(at: idx, from: dueSoon) }
                }
            }
            if !later.isEmpty {
                Section("Later") {
                    ForEach(later) { bill in
                        billRow(bill)
                    }
                    .onDelete { idx in delete(at: idx, from: later) }
                }
            }
        }
    }

    // MARK: - Views: Category Grouping

    private var categorySections: some View {
        let groups = Dictionary(grouping: bills) { (b: Bill) in
            b.category.isEmpty ? "Uncategorized" : b.category
        }
        // Sort categories by name; inside each, by due date asc
        let orderedCats = groups.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return Group {
            ForEach(orderedCats, id: \.self) { cat in
                let items = (groups[cat] ?? []).sorted { $0.anchorDueDate < $1.anchorDueDate }
                Section(cat) {
                    ForEach(items) { bill in
                        billRow(bill)
                    }
                    .onDelete { idx in delete(at: idx, from: items) }
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func billRow(_ bill: Bill) -> some View {
        NavigationLink {
            BillEditorView(existingBill: bill) { _ in }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.name.isEmpty ? "Untitled bill" : bill.name)
                        .lineLimit(1)
                    Text("\(title(for: bill.recurrence)) • \(friendlyDate(bill.anchorDueDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(formatCurrency(bill.amount))
                    .monospacedDigit()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(bill)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editingBill = bill
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        // ✅ PersistentIdentifier is not a UUID; just interpolate it for a stable string.
        .accessibilityIdentifier("BillRow_\(bill.persistentModelID)")
    }

    // MARK: - Actions

    private func delete(_ bill: Bill) {
        do {
            context.delete(bill)
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet, from source: [Bill]) {
        let targets = offsets.map { source[$0] }
        for b in targets { context.delete(b) }
        do {
            try context.save()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func title(for r: BillRecurrence) -> String {
        switch r {
        case .once: "One-time"
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .semimonthly: "Twice a Month"
        case .monthly: "Monthly"
        }
    }

    private func friendlyDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    private func formatCurrency(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }
}
