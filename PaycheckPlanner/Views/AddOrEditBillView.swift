//
//  AddOrEditBillView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Show currency symbol; commit amount on blur/other control; no insert on cancel
//

import SwiftUI
import SwiftData

/// Add or edit a bill. Handles `.once` and lets you enter a Category for Insights.
struct AddOrEditBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existingBill: Bill?
    let onComplete: (Bool) -> Void

    // Draft fields
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var amountText: String = ""
    @FocusState private var amountFocused: Bool

    @State private var dueDate: Date = .now
    @State private var recurrence: BillRecurrence = .monthly
    @State private var category: String = ""

    init(existingBill: Bill? = nil, onComplete: @escaping (Bool) -> Void = { _ in }) {
        self.existingBill = existingBill
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    // Currency input, normalized to two decimals with symbol on commit.
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("$0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($amountFocused)
                            .submitLabel(.done)
                            .onSubmit { commitAmount() }
                            .onChange(of: amountFocused) { focused in
                                if !focused { commitAmount() } // treat blur like Done
                            }
                    }

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                        .onChange(of: dueDate) { _ in commitFromOtherControl() }

                    Picker("Repeats", selection: $recurrence) {
                        ForEach(BillRecurrence.allCases, id: \.self) { r in
                            Text(r.displayName).tag(r)
                        }
                    }
                    .onChange(of: recurrence) { _ in commitFromOtherControl() }

                    TextField("Category (optional)", text: $category)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onTapGesture { commitFromOtherControl() }
                }
            }
            .navigationTitle(existingBill == nil ? "New Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onComplete(false)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        if let b = existingBill {
            name = b.name
            amount = b.amount
            amountText = amount == 0 ? "" : ppFormatCurrency(amount)
            dueDate = b.anchorDueDate
            recurrence = b.recurrence
            category = b.category
        } else {
            amount = 0
            amountText = "" // placeholder until commit
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    // MARK: - Amount Committers

    private func commitAmount() {
        let parsed = ppParseDecimal(amountText)
        amount = parsed
        amountText = parsed == 0 ? ppFormatCurrency(0) : ppFormatCurrency(parsed)
    }

    private func commitFromOtherControl() {
        if amountFocused { amountFocused = false }
        commitAmount()
    }

    // MARK: - Save

    private func save() {
        commitAmount() // final guard

        guard canSave else { return }

        if let b = existingBill {
            b.name = name
            b.amount = amount
            b.anchorDueDate = Calendar.current.startOfDay(for: dueDate)
            b.recurrence = recurrence
            b.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let b = Bill(
                name: name,
                amount: amount,
                recurrence: recurrence,
                anchorDueDate: Calendar.current.startOfDay(for: dueDate),
                category: category.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            context.insert(b)
        }

        try? context.save()
        onComplete(true)
        dismiss()
    }
}

// MARK: - Local helpers (avoid global collisions)

/// Currency string with exactly two decimals, e.g. $50.00 (uses current locale)
private func ppFormatCurrency(_ d: Decimal) -> String {
    let n = NSDecimalNumber(decimal: d)
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    f.locale = .current
    return f.string(from: n) ?? "$0.00"
}

/// Tolerant parse for "50", "50.0", "50,00", "$50.00", etc.; clamps to 2 decimals.
private func ppParseDecimal(_ s: String) -> Decimal {
    let cleaned = s
        .replacingOccurrences(of: ",", with: ".")
        .filter { "0123456789.".contains($0) }
    guard var d = Decimal(string: cleaned) else { return 0 }
    var r = Decimal()
    NSDecimalRound(&r, &d, 2, .plain)
    return r
}
