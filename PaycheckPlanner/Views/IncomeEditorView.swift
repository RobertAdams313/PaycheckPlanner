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
                        Text(uiName(for: f)).tag(f)
                    }
                }

                switch frequency {
                case .once, .weekly, .biweekly, .monthly:
                    DatePicker(
                        frequency == .once ? "Pay date" : "Anchor date",
                        selection: $anchorDate,
                        displayedComponents: .date
                    )

                case .semimonthly:
                    Stepper("First day: \(semiFirst)", value: $semiFirst, in: 1...28)
                    Stepper("Second day: \(semiSecond)", value: $semiSecond, in: 1...28)
                }
            }
        }
        .navigationTitle(existing == nil ? "New Income" : "Edit Income")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) {
                    onComplete(false); dismiss()
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
                // ensure back-link (in case it was missing)
                if sched.source == nil { sched.source = src }
            } else {
                let sched = IncomeSchedule()
                applyScheduleEdits(to: sched)
                context.insert(sched)
                // set BOTH sides
                src.schedule = sched
                sched.source = src
            }
        } else {
            // Create new
            let src = IncomeSource(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                defaultAmount: amount,
                variable: variable
            )

            let sched = IncomeSchedule()
            applyScheduleEdits(to: sched)

            // Insert before linking (safer for SwiftData to track)
            context.insert(src)
            context.insert(sched)

            // set BOTH sides
            src.schedule = sched
            sched.source = src
        }

        do {
            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            print("Failed to save income: \(error)")
            showSaveError = true
            onComplete(false)
        }
    }

    private func applyScheduleEdits(to sched: IncomeSchedule) {
        sched.frequency = frequency
        switch frequency {
        case .once, .weekly, .biweekly, .monthly:
            sched.anchorDate = anchorDate
            // reset semimonthly days
            sched.semimonthlyFirstDay = 1
            sched.semimonthlySecondDay = 15

        case .semimonthly:
            sched.anchorDate = anchorDate
            sched.semimonthlyFirstDay = semiFirst
            sched.semimonthlySecondDay = semiSecond
        }
    }

    private func uiName(for f: PayFrequency) -> String {
        switch f {
        case .once:        return "Once"
        case .weekly:      return "Weekly"
        case .biweekly:    return "Every 2 Weeks"
        case .semimonthly: return "Twice a Month"
        case .monthly:     return "Monthly"
        }
    }
}
