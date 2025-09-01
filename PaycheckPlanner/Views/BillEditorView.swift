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

    // Currency formatting for amount
    private let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    var body: some View {
        Form {
            // MARK: Details
            Section("Details") {
                TextField("Name", text: $bill.name)
                    .textInputAutocapitalization(.words)

                // Amount (Decimal) bound through string formatter bridge
                HStack {
                    Text("Amount")
                    Spacer()
                    DecimalField(value: $bill.amount, formatter: amountFormatter)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: 160)
                }
                .accessibilityElement(children: .combine)

                // NEW: Category picker (binds to bill.category String)
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
                DatePicker("Anchor Due Date", selection: $bill.anchorDueDate, displayedComponents: .date)
            }
        }
        .navigationTitle(bill.name.isEmpty ? "New Bill" : bill.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    try? context.save()
                    dismiss()
                }
                .bold()
            }
        }
    }
}

// MARK: - Decimal text field helper

/// Minimal decimal text field that binds to a Decimal via NumberFormatter.
/// Avoids accidental locale pitfalls and preserves monospaced digits.
private struct DecimalField: View {
    @Binding var value: Decimal
    let formatter: NumberFormatter
    @State private var text: String = ""

    init(value: Binding<Decimal>, formatter: NumberFormatter) {
        self._value = value
        self.formatter = formatter
        _text = State(initialValue: formatter.string(from: value.wrappedValue as NSDecimalNumber) ?? "")
    }

    var body: some View {
        TextField("0", text: $text)
            .font(.system(.body, design: .monospaced))
            .onChange(of: text) { new in
                // Parse; tolerate empty and partial input
                let cleaned = new.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.isEmpty {
                    value = 0
                } else if let num = formatter.number(from: cleaned) {
                    value = num.decimalValue
                }
            }
            .onAppear {
                text = formatter.string(from: value as NSDecimalNumber) ?? ""
            }
            .onChange(of: value) { newValue in
                let s = formatter.string(from: newValue as NSDecimalNumber) ?? ""
                if s != text { text = s }
            }
    }
}
