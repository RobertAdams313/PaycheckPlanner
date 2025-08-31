//
//  BillEditorView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  BillEditorView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct BillEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var bill: Bill

    // UI state (bridges cleanly to model types)
    @State private var amountDouble: Double = 0
    @State private var dueDate: Date = .now
    @State private var selectedFrequency: RepeatFrequency = .none

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $bill.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField(
                    "Amount",
                    value: $amountDouble,
                    format: .currency(code: Locale.current.currency?.identifier ?? "USD")
                )
                .keyboardType(.decimalPad)
                .onChange(of: amountDouble) { _, newValue in
                    // Model uses Double — assign directly
                    bill.amount = newValue
                }

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .onChange(of: dueDate) { _, newValue in
                        bill.dueDate = newValue
                    }
            }

            Section("Repeat") {
                Picker("Frequency", selection: $selectedFrequency) {
                    ForEach(RepeatFrequency.allCases, id: \.rawValue) { freq in
                        Text(freq.rawValue.capitalized).tag(freq)
                    }
                }
                .onChange(of: selectedFrequency) { _, newValue in
                    // Model stores a String — persist the enum’s rawValue (lowercased)
                    bill.repeatFrequency = newValue.rawValue
                }
            }

            Section("Category") {
                TextField("Category", text: $bill.category)
                    .textInputAutocapitalization(.words)
            }

            if bill.isPaid {
                Label("Marked as Paid", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .navigationTitle("Edit Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            // Seed UI state from model (no Decimal bridging needed)
            amountDouble = bill.amount
            dueDate = bill.dueDate
            selectedFrequency = RepeatFrequency(fuzzy: bill.repeatFrequency)
        }
    }
}
