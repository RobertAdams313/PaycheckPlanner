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
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

/// Bills list + Add (+) button. Calendar push toggle & “Push Now”. Sorting restored.
struct BillsView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    @State private var editingBill: Bill?
    @State private var showEditor = false

    @AppStorage("pushBillsToCalendar") private var pushBillsToCalendar: Bool = false
    @AppStorage("billAlertDaysBefore") private var billAlertDaysBefore: Int = 1

    // Persisted sort mode (Next Due Date by default)
    @AppStorage("billsSortMode")
    private var sortModeRaw: Int = BillsSortMode.nextDueDate.rawValue

    private var sortMode: BillsSortMode {
        BillsSortMode(rawValue: sortModeRaw) ?? .nextDueDate
    }

    // One place to order the list
    private var sortedBills: [Bill] {
        switch sortMode {
        case .nextDueDate:
            return bills.sorted { $0.anchorDueDate < $1.anchorDueDate }
        case .category:
            // Empty category sorts last (tilde trick)
            return bills.sorted {
                let l = $0.category.isEmpty ? "~" : $0.category
                let r = $1.category.isEmpty ? "~" : $1.category
                if l.caseInsensitiveCompare(r) == .orderedSame {
                    return $0.anchorDueDate < $1.anchorDueDate
                }
                return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedBills.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Text("No bills yet").font(.headline)
                            Text("Tap the + button to add your first bill.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                } else {
                    ForEach(sortedBills) { bill in
                        Button { editingBill = bill } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bill.name).font(.body)
                                    Text("\(bill.anchorDueDate, style: .date) • \(bill.recurrence.displayName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(bill.amount.currencyString)
                                    .monospacedDigit()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Bills")
            .toolbar {
                // Calendar push menu
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("Push Bills to Calendar", isOn: $pushBillsToCalendar)
                        Stepper("Alert \(billAlertDaysBefore) day(s) before",
                                value: $billAlertDaysBefore,
                                in: 0...14)
                        Divider()
                        // Sorting control (restores earlier enhancement)
                        Picker("Sort Bills", selection: $sortModeRaw) {
                            ForEach(BillsSortMode.allCases, id: \.rawValue) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        Divider()
                        Button("Push Now") { pushBillsNow() }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
                // Add (+)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // New bill
            .sheet(isPresented: $showEditor) {
                BillEditorView(bill: Bill())
            }
            // Edit existing bill
            .sheet(item: $editingBill) { bill in
                BillEditorView(bill: bill)
            }
            .onChange(of: pushBillsToCalendar) { newVal in
                if newVal { pushBillsNow() }
            }
        }
    }

    // MARK: - Calendar push
    private func pushBillsNow() {
        Task {
            do {
                for b in bills {
                    try await CalendarManager.shared.addBillEvent(
                        name: b.name,
                        amount: b.amount,
                        dueDate: b.anchorDueDate,
                        recurrence: b.recurrence.displayName,
                        alertDaysBefore: billAlertDaysBefore
                    )
                }
            } catch {
                // Silently ignore for now; could show a toast
                print("Calendar push failed: \(error)")
            }
        }
    }
}

// MARK: - Local sort enum (scoped to avoid redeclarations elsewhere)
private enum BillsSortMode: Int, CaseIterable {
    case nextDueDate = 0
    case category = 1

    var label: String {
        switch self {
        case .nextDueDate: return "Next Due Date"
        case .category:    return "Category"
        }
    }
}
