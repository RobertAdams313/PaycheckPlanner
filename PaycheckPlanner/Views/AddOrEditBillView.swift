//
//  AddOrEditBillView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Add or edit a bill. Handles `.once` and lets you enter a Category for Insights.
struct AddOrEditBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existingBill: Bill?
    let onComplete: (Bool) -> Void

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var dueDate: Date = .now
    @State private var recurrence: BillRecurrence = .monthly
    @State private var category: String = ""     // NEW

    init(existingBill: Bill? = nil, onComplete: @escaping (Bool) -> Void = { _ in }) {
        self.existingBill = existingBill
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    Picker("Repeats", selection: $recurrence) {
                        ForEach(BillRecurrence.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                    TextField("Category (optional)", text: $category)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(existingBill == nil ? "New Bill" : "Edit Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete(false); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    private func bootstrap() {
        if let b = existingBill {
            name = b.name
            amount = b.amount
            dueDate = b.anchorDueDate
            recurrence = b.recurrence
            category = b.category
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount >= 0
    }

    private func save() {
        if let b = existingBill {
            b.name = name
            b.amount = amount
            b.anchorDueDate = dueDate
            b.recurrence = recurrence
            b.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let b = Bill(
                name: name,
                amount: amount,
                recurrence: recurrence,
                anchorDueDate: dueDate,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            context.insert(b)
        }
        try? context.save()
        onComplete(true)
        dismiss()
    }
}

