//
//  IncomeEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  IncomeEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/1/25
//

import SwiftUI
import SwiftData

struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// If non-nil, we’re editing an existing source.
    let existing: IncomeSource?

    // MARK: - Inputs
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var variable: Bool = false

    // Schedule fields
    @State private var frequency: PayFrequency = .biweekly
    @State private var anchorDate: Date = .now
    @State private var semimonthlyFirstDay: Int = 1
    @State private var semimonthlySecondDay: Int = 15

    // UI
    @FocusState private var nameFocused: Bool
    @FocusState private var amountFocused: Bool
    @State private var showSaveError = false

    // MARK: - Init with existing model data
    init(existing: IncomeSource? = nil) {
        self.existing = existing
        // State is hydrated in .task (after modelContext is available) for reliability.
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($nameFocused)

                    // Currency input using a Double bridge to keep Decimal in the model
                    TextField("Amount", value: amountDoubleBinding, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                        .focused($amountFocused)

                    Toggle("Variable amount", isOn: $variable)
                        .help("Turn on if this income varies; you can still set a typical amount.")
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        Text("Weekly").tag(PayFrequency.weekly)
                        Text("Biweekly").tag(PayFrequency.biweekly)
                        Text("Semimonthly").tag(PayFrequency.semimonthly)
                        Text("Monthly").tag(PayFrequency.monthly)
                    }

                    DatePicker("Start Date", selection: $anchorDate, displayedComponents: .date)
                        .help("The reference date used to compute future paydays.")

                    if frequency == .semimonthly {
                        HStack {
                            Stepper(value: $semimonthlyFirstDay, in: 1...28) {
                                Text("First day")
                            }
                            Spacer()
                            Text("\(semimonthlyFirstDay)").foregroundStyle(.secondary)
                        }

                        HStack {
                            Stepper(value: $semimonthlySecondDay, in: 1...28) {
                                Text("Second day")
                            }
                            Spacer()
                            Text("\(semimonthlySecondDay)").foregroundStyle(.secondary)
                        }
                    }
                }

                if showSaveError {
                    Section {
                        Text("Couldn’t save your income. Please try again.")
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Income" : "Edit Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .task { hydrateFromExistingIfNeeded() }
        }
    }

    // MARK: - Validation
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Amount <-> Double bridge (for TextField w/ .currency format)
    private var amountDoubleBinding: Binding<Double> {
        Binding<Double>(
            get: {
                (amount as NSDecimalNumber).doubleValue
            },
            set: { newVal in
                amount = Decimal(Double(newVal))
            }
        )
    }

    // MARK: - Load existing values into state
    private func hydrateFromExistingIfNeeded() {
        guard let src = existing else { return }
        name = src.name
        amount = src.defaultAmount
        variable = src.variable

        if let sched = src.schedule {
            frequency = sched.frequency
            anchorDate = sched.anchorDate
            semimonthlyFirstDay = sched.semimonthlyFirstDay
            semimonthlySecondDay = sched.semimonthlySecondDay
        }
    }

    // MARK: - Save
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let src = existing {
            // Update existing
            src.name = trimmedName
            src.defaultAmount = amount
            src.variable = variable

            if let sched = src.schedule {
                applyScheduleEdits(to: sched)
                if sched.source == nil { sched.source = src } // critical
            } else {
                let sched = IncomeSchedule(source: src)
                applyScheduleEdits(to: sched)
                context.insert(sched)
                src.schedule = sched
            }
        } else {
            // New income + schedule
            let src = IncomeSource(name: trimmedName, defaultAmount: amount, variable: variable)
            let sched = IncomeSchedule(source: src)
            applyScheduleEdits(to: sched)

            context.insert(src)
            context.insert(sched)
            src.schedule = sched
        }

        do {
            try context.save()
            dismiss()
            // inside save() after try context.save()
            do {
                try context.save()
                print("✅ Saved income: \(trimmedName) amount: \(amount)")
                dismiss()
            } catch {
                print("❌ Save failed: \(error.localizedDescription)")
                showSaveError = true
            }

        } catch {
            showSaveError = true
        }
    }


    // MARK: - Apply schedule edits (the helper you were missing)
    private func applyScheduleEdits(to sched: IncomeSchedule) {
        sched.frequency = frequency
        sched.anchorDate = anchorDate
        sched.semimonthlyFirstDay = semimonthlyFirstDay
        sched.semimonthlySecondDay = semimonthlySecondDay
    }
}
