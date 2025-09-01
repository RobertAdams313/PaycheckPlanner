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

import SwiftUI
import SwiftData

struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// When non-nil we edit, otherwise we create.
    let existing: IncomeSource?

    // MARK: - State
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var variable: Bool = false

    @State private var frequency: PayFrequency = .biweekly
    @State private var anchorDate: Date = .now
    @State private var semiFirst: Int = 1
    @State private var semiSecond: Int = 15

    @State private var showSaveError = false
    var onComplete: (Bool) -> Void = { _ in }

    var body: some View {
        Form {
            Section("Income") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                CurrencyAmountField(amount: $amount)

                Toggle("Variable amount", isOn: $variable)
            }

            Section("Pay Schedule") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(PayFrequency.allCases) { f in
                        Text(f.uiName).tag(f)
                    }
                }

                switch frequency {
                case .once, .weekly, .biweekly, .monthly:
                    DatePicker(frequency == .once ? "Pay date"
                                                  : "Anchor date",
                               selection: $anchorDate,
                               displayedComponents: .date)

                case .semimonthly:
                    Stepper("First day: \(semiFirst)", value: $semiFirst, in: 1...28)
                    Stepper("Second day: \(semiSecond)", value: $semiSecond, in: 1...28)
                }
            }
        }
        .navigationTitle(existing == nil ? "New Income" : "Edit Income")
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
        .alert("Couldn’t Save Income",
               isPresented: $showSaveError,
               actions: { Button("OK", role: .cancel) {} },
               message: { Text("Please try again.") })
    }

    // MARK: - Bootstrap

    private func bootstrap() {
        guard let src = existing else { return }
        name = src.name
        amount = src.defaultAmount
        variable = src.variable

        if let sched = src.schedule {
            frequency = sched.frequency
            anchorDate = sched.anchorDate
            semiFirst = sched.semimonthlyFirstDay
            semiSecond = sched.semimonthlySecondDay
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount > 0
    }

    // MARK: - Save

    private func save() {
        if let src = existing {
            // Update existing
            src.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            src.defaultAmount = amount
            src.variable = variable

            if let sched = src.schedule {
                applyScheduleEdits(to: sched)
            } else {
                let sched = IncomeSchedule()
                applyScheduleEdits(to: sched)
                context.insert(sched)
                src.schedule = sched
            }
        } else {
            // Create new
            let src = IncomeSource(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                   defaultAmount: amount,
                                   variable: variable)
            let sched = IncomeSchedule()
            applyScheduleEdits(to: sched)
            context.insert(sched)
            src.schedule = sched
            context.insert(src)
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

    private func applyScheduleEdits(to sched: IncomeSchedule) {
        sched.frequency = frequency
        switch frequency {
        case .once, .weekly, .biweekly, .monthly:
            sched.anchorDate = anchorDate
        case .semimonthly:
            // Keep anchorDate for consistency (not used by stride logic),
            // but store the two semimonthly days.
            sched.anchorDate = anchorDate
            sched.semimonthlyFirstDay = semiFirst
            sched.semimonthlySecondDay = semiSecond
        }
    }
}

// Convenience accessors if you used these previously
private extension IncomeSchedule {
    var semiMonthlyFirst: Int { semimonthlyFirstDay }
    var semiMonthlySecond: Int { semimonthlySecondDay }
}
