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

/// Bills list + Add (+) button. Adds Calendar push toggle & “Push Now”.
struct BillsView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context

    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    @State private var editingBill: Bill?
    @State private var showEditor = false

    @AppStorage("pushBillsToCalendar") private var pushBillsToCalendar: Bool = false
    @AppStorage("billAlertDaysBefore") private var billAlertDaysBefore: Int = 1

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
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("Push Bills to Calendar", isOn: $pushBillsToCalendar)
                        Stepper("Alert \(billAlertDaysBefore) day(s) before", value: $billAlertDaysBefore, in: 0...14)
                        Divider()
                        Button("Push Now") { pushBillsNow() }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // New bill (BillEditorView expects a non-optional Bill and no onComplete:)
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
                // Silently ignore for now; could show a toast/toaster view
                print("Calendar push failed: \(error)")
            }
        }
    }
}
