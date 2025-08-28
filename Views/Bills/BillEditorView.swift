//
//  BillEditorView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct BillEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var dueDate: Date = Date()
    @State private var repeatFrequency: String = "monthly"

    private let frequenciesDisplay: [(label: String, value: String)] = [
        ("One-Time", "one-time"),
        ("Weekly", "weekly"),
        ("Biweekly", "biweekly"),
        ("Monthly", "monthly"),
        ("Yearly", "yearly")
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .nameAutoCap(text: $name)

                TextField("Amount", text: $amountString)
                    .currencyInput(text: $amountString, currencyCode: Locale.current.currency?.identifier)

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)

                Picker("Repeat", selection: $repeatFrequency) {
                    ForEach(frequenciesDisplay, id: \.value) { item in
                        Text(item.label).tag(item.value)
                    }
                }
            }
            .navigationTitle("New Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let amount = CurrencyInput.parseDouble(amountString)
                        let bill = Bill(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            amount: amount,
                            dueDate: dueDate,
                            repeatFrequency: repeatFrequency
                        )
                        context.insert(bill)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
