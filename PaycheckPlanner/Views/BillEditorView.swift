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

import SwiftUI
import SwiftData

/// Create or edit a Bill. Uses a real currency field and saves into SwiftData.
struct BillEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Existing bill if editing
    let existingBill: Bill?

    // Inputs
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var dueDate: Date = .now
    @State private var recurrence: BillRecurrence = .monthly
    @State private var category: String = ""

    // UI
    @FocusState private var amountFocused: Bool
    @State private var showSaveError = false
    var onComplete: (Bool) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)   // <- capitalize words as you type
                        .disableAutocorrection(true)
                        .onChange(of: name) { _, newValue in
                            // Keep it light: let the system handle caps,
                            // but trim accidental leading spaces.
                            if newValue.hasPrefix(" ") {
                                name = String(newValue.drop(while: { $0 == " " }))
                            }
                        }

                    CurrencyAmountField(amount: $amount)

                        .focused($amountFocused)

                    DatePicker("First Due Date", selection: $dueDate, displayedComponents: .date)

                    Picker("Repeats", selection: $recurrence) {
                        ForEach(BillRecurrence.allCasesForBillEditor, id: \.self) { r in
                            Text(r.uiName).tag(r)
                        }
                    }
                }

                Section("Category (optional)") {
                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    private func bootstrap() {
        guard let bill = existingBill else { return }
        name = bill.name
        amount = bill.amount
        dueDate = bill.anchorDueDate
        recurrence = bill.recurrence
        category = bill.category
    }

    private func save() {
        if let bill = existingBill {
            bill.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            bill.amount = amount
            bill.anchorDueDate = dueDate
            bill.recurrence = recurrence
            bill.category = category
        } else {
            let b = Bill(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                         amount: amount,
                         recurrence: recurrence,
                         anchorDueDate: dueDate,
                         category: category)
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
