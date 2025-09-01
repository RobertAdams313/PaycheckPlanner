//
//  BillEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  BillEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct BillEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // SwiftData model
    @Bindable var bill: Bill

    @State private var showSaveError = false

    private var canSave: Bool {
        !bill.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        bill.amount >= 0 // change to > 0 if you want to require positive
    }

    var body: some View {
        Form {
            // MARK: Details
            Section("Details") {
                TextField("Name", text: $bill.name)
                    .textInputAutocapitalization(.words)

                // Match IncomeEditorView’s currency behavior
                HStack {
                    Text("Amount")
                    Spacer()
                    CurrencyAmountField(amount: $bill.amount)
                        .frame(maxWidth: 160)
                }
                .accessibilityElement(children: .combine)

                // Category picker (binds to bill.category String)
                CategoryPicker(category: $bill.category)
            }

            // MARK: Schedule
            Section("Schedule") {
                Picker("Repeats", selection: $bill.recurrence) {
                    Text("Once").tag(BillRecurrence.once)
                    Text("Weekly").tag(BillRecurrence.weekly)
                    Text("Every 2 Weeks").tag(BillRecurrence.biweekly)
                    Text("Monthly").tag(BillRecurrence.monthly)
                    Text("Twice a Month").tag(BillRecurrence.semimonthly)
                }
                .pickerStyle(.menu)

                // Anchor / due date (first occurrence)
                DatePicker("Anchor Due Date",
                           selection: $bill.anchorDueDate,
                           displayedComponents: .date)
            }
        }
        .navigationTitle(bill.name.isEmpty ? "New Bill" : bill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: save)
                    .bold()
                    .disabled(!canSave)
            }
        }
        .alert("Couldn’t Save Bill", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: { Text("Please try again.") }
    }

    private func save() {
        // Insert if new
        if bill.persistentModelID == nil {
            context.insert(bill)
        }
        do {
            try context.save()
            dismiss()
        } catch {
            print("Failed to save bill: \(error)")
            showSaveError = true
        }
    }
}
