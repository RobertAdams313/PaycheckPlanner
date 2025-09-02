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
//  Updated on 9/1/25
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
    @State private var errorMessage = ""

    /// Called after a successful save or delete (optional hook for parent)
    var onComplete: (Bool) -> Void = { _ in }

    // MARK: - Init
    init(existingBill: Bill? = nil, onComplete: @escaping (Bool) -> Void = { _ in }) {
        self.existingBill = existingBill
        self.onComplete = onComplete
    }

    // MARK: - Body
    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                    .modifier(NameAutoCapModifier(text: $name))

                CurrencyField("Amount", value: $amount)
                    .focused($amountFocused)

                Picker("Recurrence", selection: $recurrence) {
                    ForEach(BillRecurrence.allCases) { r in
                        Text(title(for: r)).tag(r)
                    }
                }

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .help("Anchor date used with the recurrence to compute occurrences.")
            }

            Section("Category") {
                TextField("Category (optional)", text: $category)
                    .modifier(NameAutoCapModifier(text: $category))
            }

            if existingBill != nil {
                Section {
                    Button(role: .destructive) { deleteBill() } label: {
                        Label("Delete Bill", systemImage: "trash")
                    }
                }
            }

            if showSaveError {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("BillEditorErrorText")
                }
            }
        }
        .navigationTitle(existingBill == nil ? "New Bill" : "Edit Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveBill() }
                    .disabled(!isValid)
                    .bold()
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .onAppear(perform: loadIfEditing)
    }

    // MARK: - Validation
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    private func title(for r: BillRecurrence) -> String {
        switch r {
        case .once: "One-time"
        case .weekly: "Weekly"
        case .biweekly: "Every 2 Weeks"
        case .semimonthly: "Twice a Month"
        case .monthly: "Monthly"
        }
    }

    // MARK: - Lifecycle
    private func loadIfEditing() {
        guard let b = existingBill else { return }
        name = b.name
        amount = b.amount
        recurrence = b.recurrence
        dueDate = b.anchorDueDate
        category = b.category
    }

    // MARK: - Actions
    private func saveBill() {
        guard isValid else { return }

        do {
            if let b = existingBill {
                // Edit in place
                b.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                b.amount = amount
                b.recurrence = recurrence
                b.anchorDueDate = Calendar.current.startOfDay(for: dueDate)
                b.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Create
                let b = Bill(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amount,
                    recurrence: recurrence,
                    anchorDueDate: Calendar.current.startOfDay(for: dueDate),
                    category: category.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                context.insert(b)
            }

            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func deleteBill() {
        guard let b = existingBill else { return }
        do {
            context.delete(b)
            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}

//
// MARK: - CurrencyField
//

/// A lightweight currency field that binds a Decimal while showing localized currency text.
fileprivate struct CurrencyField: View {
    let title: String
    @Binding var value: Decimal

    @State private var text: String = ""
    @FocusState private var focused: Bool

    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    init(_ title: String, value: Binding<Decimal>) {
        self.title = title
        _value = value
        _text = State(initialValue: CurrencyField.fmt.string(from: NSDecimalNumber(decimal: value.wrappedValue)) ?? "")
    }

    var body: some View {
        TextField(title, text: $text, onEditingChanged: { began in
            if !began { commit() }
        })
        .keyboardType(.decimalPad)
        .onChange(of: text) { _ in
            // live-parse to Decimal, allow partial typing
            value = parseDecimal(from: text) ?? value
        }
        .onAppear {
            text = CurrencyField.fmt.string(from: NSDecimalNumber(decimal: value)) ?? ""
        }
        .onSubmit { commit() }
        .accessibilityIdentifier("CurrencyTextField")
    }

    private func commit() {
        let dec = parseDecimal(from: text) ?? value
        value = dec
        text = CurrencyField.fmt.string(from: NSDecimalNumber(decimal: dec)) ?? ""
    }

    private func parseDecimal(from s: String) -> Decimal? {
        // Strip non-numeric except decimal separator
        let decSep = Locale.current.decimalSeparator ?? "."
        let allowed = CharacterSet(charactersIn: "0123456789" + decSep)
        let raw = String(s.unicodeScalars.filter { allowed.contains($0) })
            .replacingOccurrences(of: decSep, with: ".")
        if raw.isEmpty { return 0 }
        return Decimal(string: raw)
    }
}
