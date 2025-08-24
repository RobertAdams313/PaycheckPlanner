//
//  BillEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

/// Create or edit a Bill. Uses a real currency field and saves into SwiftData.
struct BillEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existingBill: Bill?          // nil = create
    let onComplete: (Bool) -> Void   // true = saved, false = canceled

    // Form state
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var dueDate: Date = .now
    @State private var recurrence: BillRecurrence = .monthly
    @State private var showSaveError = false

    init(existingBill: Bill?, onComplete: @escaping (Bool) -> Void) {
        self.existingBill = existingBill
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)

                    // ✅ Always displays as currency, uses numeric keypad
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)

                    DatePicker("First Due Date", selection: $dueDate, displayedComponents: .date)

                    Picker("Repeats", selection: $recurrence) {
                        ForEach(BillRecurrence.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                }
            }
            .navigationTitle(existingBill == nil ? "New Bill" : "Edit Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: bootstrap)
            .alert("Couldn’t Save Bill",
                   isPresented: $showSaveError,
                   actions: { Button("OK", role: .cancel) {} },
                   message: { Text("Please try again.") })
        }
    }

    private func bootstrap() {
        if let b = existingBill {
            name = b.name
            amount = b.amount
            dueDate = b.anchorDueDate
            recurrence = b.recurrence
        } else {
            dueDate = .now
            recurrence = .monthly
            amount = 0
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
        } else {
            let b = Bill(name: name, amount: amount, recurrence: recurrence, anchorDueDate: dueDate)
            context.insert(b)
        }

        do {
            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            showSaveError = true
            onComplete(false)
        }
    }
}
