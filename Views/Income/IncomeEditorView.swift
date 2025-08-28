//
//  IncomeEditorView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var amountString: String = ""
    @State private var frequency: String = "biweekly"
    @State private var startDate: Date = Date()

    private let frequenciesDisplay: [(label: String, value: String)] = [
        ("Weekly", "weekly"),
        ("Biweekly", "biweekly"),
        ("Monthly", "monthly")
    ]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .nameAutoCap(text: $name)

                TextField("Amount", text: $amountString)
                    .currencyInput(text: $amountString, currencyCode: Locale.current.currency?.identifier)

                Picker("Frequency", selection: $frequency) {
                    ForEach(frequenciesDisplay, id: \.value) { item in
                        Text(item.label).tag(item.value)
                    }
                }

                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            }
            .navigationTitle("New Income Source")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let amount = CurrencyInput.parseDouble(amountString)
                        let income = IncomeSource(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            amount: amount,
                            frequency: frequency,
                            startDate: startDate
                        )
                        context.insert(income)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
