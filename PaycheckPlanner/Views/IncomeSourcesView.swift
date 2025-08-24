//
//  IncomeSourcesView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.name, order: .forward) private var incomes: [IncomeSource]

    @State private var editing: IncomeSource?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                if incomes.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Text("No income sources yet").font(.headline)
                            Text("Tap + to add your first source and its pay schedule.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                    }
                } else {
                    ForEach(incomes) { src in
                        Button { editing = src } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(src.name)
                                    if let sch = src.schedule {
                                        Text(scheduleSummary(sch))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(formatCurrency(src.defaultAmount)).font(.headline)
                                if src.variable {
                                    Image(systemName: "slider.horizontal.3")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(incomes[i]) }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Income")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) {
                IncomeSourceEditorSheet(existing: nil) { saved in
                    adding = false
                }
            }
            .sheet(item: $editing) { src in
                IncomeSourceEditorSheet(existing: src) { _ in editing = nil }
            }
        }
    }

    private func scheduleSummary(_ s: IncomeSchedule) -> String {
        switch s.frequency {
        case .weekly:
            return "Weekly • \(s.anchorDate.formatted(date: .abbreviated, time: .omitted))"
        case .biweekly:
            return "Every 2 Weeks • \(s.anchorDate.formatted(date: .abbreviated, time: .omitted))"
        case .semimonthly:
            return "Semi-monthly • \(s.semimonthlyFirstDay) & \(s.semimonthlySecondDay)"
        case .monthly:
            let day = Calendar.current.component(.day, from: s.anchorDate)
            return "Monthly • day \(day)"
        }
    }

    private func formatCurrency(_ v: Decimal, code: String = "USD") -> String {
        let n = NSDecimalNumber(decimal: v)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "0.00"
    }
}

// MARK: - Embedded Editor (renamed + fixed helpers)

private struct IncomeSourceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let existing: IncomeSource?
    let onClose: (Bool) -> Void

    @State private var name = ""
    @State private var amountText = "0.00"    // shows 0.00, clears on first tap
    @FocusState private var amountFocused: Bool

    @State private var variable = false
    @State private var frequency: PayFrequency = .biweekly
    @State private var anchorDate = Date()
    @State private var semi1 = 1
    @State private var semi2 = 15

    init(existing: IncomeSource?, onClose: @escaping (Bool) -> Void) {
        self.existing = existing
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Income") {
                    TextField("Name", text: $name)

                    // Clears "0.00" on first interaction; formats on blur/submit
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .onTapGesture {
                            if amountText == "0.00" { amountText = "" }
                        }
                        .onSubmit { normalizeAmount() }
                        .onChange(of: amountFocused) { _, newFocused in
                            if !newFocused { normalizeAmount() }
                        }

                    Toggle("Variable amount", isOn: $variable)
                }

                Section("Pay Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(PayFrequency.allCases) { f in Text(f.displayName).tag(f) }
                    }
                    switch frequency {
                    case .weekly, .biweekly, .monthly:
                        DatePicker("Anchor date", selection: $anchorDate, displayedComponents: .date)
                    case .semimonthly:
                        Stepper(value: $semi1, in: 1...28) { Text("First day: \(semi1)") }
                        Stepper(value: $semi2, in: 1...28) { Text("Second day: \(semi2)") }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Income" : "Edit Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onClose(false); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .onAppear(perform: bootstrap)
        }
    }

    private func bootstrap() {
        if let src = existing {
            name = src.name
            amountText = formatCurrencyString(src.defaultAmount)
            variable = src.variable

            if let s = src.schedule {
                frequency = s.frequency
                anchorDate = s.anchorDate
                semi1 = s.semimonthlyFirstDay
                semi2 = s.semimonthlySecondDay
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parseDecimal(from: amountText) != nil
    }

    private func save() {
        let amount = parseDecimal(from: amountText) ?? 0

        if let src = existing {
            src.name = name
            src.defaultAmount = amount
            src.variable = variable
            if let s = src.schedule {
                s.frequency = frequency
                s.anchorDate = anchorDate
                s.semimonthlyFirstDay = semi1
                s.semimonthlySecondDay = semi2
            } else {
                src.schedule = IncomeSchedule(source: src,
                                              frequency: frequency,
                                              anchorDate: anchorDate,
                                              semimonthlyFirstDay: semi1,
                                              semimonthlySecondDay: semi2)
            }
        } else {
            let src = IncomeSource(name: name, defaultAmount: amount, variable: variable)
            let s = IncomeSchedule(source: src,
                                   frequency: frequency,
                                   anchorDate: anchorDate,
                                   semimonthlyFirstDay: semi1,
                                   semimonthlySecondDay: semi2)
            src.schedule = s
            context.insert(src)
        }
        try? context.save()
        onClose(true)
        dismiss()
    }

    // MARK: - Currency helpers (renamed to avoid clashes)

    private func normalizeAmount() {
        if amountText.trimmingCharacters(in: .whitespaces).isEmpty {
            amountText = "0.00"
        } else if let d = parseDecimal(from: amountText) {
            amountText = formatCurrencyString(d)
        }
    }

    private func parseDecimal(from text: String) -> Decimal? {
        let clean = text.replacingOccurrences(of: ",", with: "")
        if let n = Decimal(string: clean) { return n }
        let f = NumberFormatter(); f.numberStyle = .decimal
        if let n = f.number(from: text) { return n.decimalValue }
        return nil
    }

    private func formatCurrencyString(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "0.00"
    }
}
