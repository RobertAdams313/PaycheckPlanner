//
//  IncomeEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existing: IncomeSource?         // nil = create
    let onComplete: (Bool) -> Void

    // Income fields
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var isVariable: Bool = false

    // Schedule fields
    @State private var frequency: PayFrequency = .biweekly
    @State private var anchorDate: Date = .now
    @State private var semiFirst: Int = 1
    @State private var semiSecond: Int = 15

    @Query private var schedules: [IncomeSchedule]

    init(existing: IncomeSource?, onComplete: @escaping (Bool) -> Void) {
        self.existing = existing
        self.onComplete = onComplete
        _schedules = Query(sort: \IncomeSchedule.anchorDate, order: .forward)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Income") {
                    TextField("Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    Toggle("Variable amount", isOn: $isVariable)
                }

                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PayFrequency.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }

                    DatePicker("Anchor payday", selection: $anchorDate, displayedComponents: .date)

                    if frequency == .semimonthly {
                        Stepper("1st day: \(semiFirst)", value: $semiFirst, in: 1...28)
                        Stepper("2nd day: \(semiSecond)", value: $semiSecond, in: 1...28)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Income" : "Edit Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete(false); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    private func bootstrap() {
        if let src = existing {
            name = src.name
            amount = src.defaultAmount
            isVariable = src.variable

            if let sch = schedules.first(where: { $0.source === src }) {
                frequency = sch.frequency
                anchorDate = sch.anchorDate
                semiFirst = sch.semiMonthlyFirst
                semiSecond = sch.semiMonthlySecond
            }
        } else {
            anchorDate = .now
            frequency = .biweekly
            amount = 0
            semiFirst = 1
            semiSecond = 15
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amount >= 0
    }

    private func save() {
        if let src = existing {
            // Update source
            src.name = name
            src.defaultAmount = amount
            src.variable = isVariable

            // Upsert schedule
            if let s = schedules.first(where: { $0.source === src }) {
                s.frequency = frequency
                s.anchorDate = anchorDate
                s.semimonthlyFirstDay = semiFirst
                s.semimonthlySecondDay = semiSecond
            } else {
                let s = IncomeSchedule(
                    source: src,
                    frequency: frequency,
                    anchorDate: anchorDate,
                    semimonthlyFirstDay: semiFirst,
                    semimonthlySecondDay: semiSecond
                )
                context.insert(s)
            }
        } else {
            // Create source + schedule
            let src = IncomeSource(name: name, defaultAmount: amount, variable: isVariable)
            context.insert(src)
            let s = IncomeSchedule(
                source: src,
                frequency: frequency,
                anchorDate: anchorDate,
                semimonthlyFirstDay: semiFirst,
                semimonthlySecondDay: semiSecond
            )
            context.insert(s)
        }

        do {
            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            onComplete(false)
        }
    }
}

// Convenience accessors matching property names used above
private extension IncomeSchedule {
    var semiMonthlyFirst: Int { semimonthlyFirstDay }
    var semiMonthlySecond: Int { semimonthlySecondDay }
}
