//
//  IncomeEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Amount editor clears on focus & auto-commits on blur; safe schedule bindings; Delete button
//

import SwiftUI
import SwiftData

// MARK: - Currency helpers

private func ppFormatCurrency(_ d: Decimal) -> String {
    let n = NSDecimalNumber(decimal: d)
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    return f.string(from: n) ?? "$0.00"
}

private func parseDecimal(from s: String) -> Decimal {
    // Accept digits and one dot/comma; simple, locale-tolerant parse.
    let dec = s
        .replacingOccurrences(of: ",", with: ".")
        .filter { "0123456789.".contains($0) }
    return Decimal(string: dec) ?? 0
}

struct IncomeEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Bind to the SwiftData model that was passed in.
    @Bindable var source: IncomeSource

    // Text editing state for currency field
    @State private var amountText: String = ""
    @FocusState private var amountFocused: Bool

    @State private var showDeleteConfirm = false

    // MARK: - Init

    init(existing: IncomeSource) {
        self._source = Bindable(existing)
        // amountText is set in .onAppear so we can decide to show "" when value is 0
    }

    // MARK: - View

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $source.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                // Currency editor (String-backed)
                TextField("Default amount", text: $amountText, prompt: Text("$0.00"))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .onChange(of: amountFocused) { focused in
                        if focused {
                            // Clear placeholder for clean entry when focusing an empty/zero value
                            if source.defaultAmount == 0, amountText.isEmpty || amountText == ppFormatCurrency(0) {
                                amountText = ""
                            }
                        } else {
                            commitAmount() // auto-confirm as soon as focus leaves
                        }
                    }
                    .onSubmit { commitAmount() } // in case a keyboard “Done” is present

                Toggle("Variable amount", isOn: $source.variable)
                    .onTapGesture { amountFocused = false } // finalize before toggling
            }

            Section("Schedule") {
                // Ensure a schedule exists, then build safe explicit bindings (no force unwraps)
                let sched = ensureSchedule()

                let freqBinding = Binding<PayFrequency>(
                    get: { sched.frequency },
                    set: { new in
                        sched.frequency = new
                        source.schedule = sched
                    }
                )

                let dateBinding = Binding<Date>(
                    get: { sched.anchorDate },
                    set: { new in
                        sched.anchorDate = new
                        source.schedule = sched
                    }
                )

                let firstDayBinding = Binding<Int>(
                    get: { sched.semimonthlyFirstDay },
                    set: { new in
                        sched.semimonthlyFirstDay = new
                        source.schedule = sched
                    }
                )

                let secondDayBinding = Binding<Int>(
                    get: { sched.semimonthlySecondDay },
                    set: { new in
                        sched.semimonthlySecondDay = new
                        source.schedule = sched
                    }
                )

                Picker("Frequency", selection: freqBinding) {
                    Text("One-time").tag(PayFrequency.once)
                    Text("Weekly").tag(PayFrequency.weekly)
                    Text("Bi-weekly").tag(PayFrequency.biweekly)
                    Text("Semi-monthly").tag(PayFrequency.semimonthly)
                    Text("Monthly").tag(PayFrequency.monthly)
                }
                .onTapGesture { amountFocused = false } // commit amount before interacting

                DatePicker("Starts", selection: dateBinding, displayedComponents: .date)
                    .onTapGesture { amountFocused = false }

                if sched.frequency == .semimonthly {
                    Stepper(value: firstDayBinding, in: 1...28) {
                        Text("First day: \(sched.semimonthlyFirstDay)")
                    }
                    .onTapGesture { amountFocused = false }

                    Stepper(value: secondDayBinding, in: 1...28) {
                        Text("Second day: \(sched.semimonthlySecondDay)")
                    }
                    .onTapGesture { amountFocused = false }
                }
            }

            Section {
                Button(role: .destructive) {
                    amountFocused = false // finalize any edit before delete
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Income", systemImage: "trash")
                }
            }
        }
        .navigationTitle(source.name.isEmpty ? "Income" : source.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Seed the editor string. If zero, start blank so placeholder shows and clears on focus.
            if source.defaultAmount == 0 {
                amountText = ""
            } else {
                amountText = ppFormatCurrency(source.defaultAmount)
            }
            _ = ensureSchedule()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    amountFocused = false // commit then close
                    dismiss()
                }
            }
        }
        .alert("Delete this income?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the income source\(source.schedule != nil ? " and its schedule" : ""). This action cannot be undone.")
        }
    }

    // MARK: - Helpers

    /// Confirm/commit the `amountText` into `source.defaultAmount`, and reformat the field.
    private func commitAmount() {
        let newValue = parseDecimal(from: amountText)
        source.defaultAmount = newValue
        // Show formatted currency unless zero (let placeholder remain visually)
        if newValue == 0 {
            amountText = ""
        } else {
            amountText = ppFormatCurrency(newValue)
        }
    }

    /// Guarantee a schedule exists so bindings are safe.
    @discardableResult
    private func ensureSchedule() -> IncomeSchedule {
        if let s = source.schedule {
            return s
        } else {
            let s = IncomeSchedule(source: source, frequency: .biweekly, anchorDate: Date())
            source.schedule = s
            return s
        }
    }

    private func performDelete() {
        if let s = source.schedule { context.delete(s) }
        context.delete(source)
        do { try context.save() } catch { /* non-fatal */ }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: IncomeSource.self, IncomeSchedule.self,
        configurations: .init(isStoredInMemoryOnly: true)
    )

    let src = IncomeSource(name: "Paycheck", defaultAmount: 2500, variable: false, schedule: nil)
    let sched = IncomeSchedule(source: src, frequency: .biweekly, anchorDate: Date())
    src.schedule = sched

    return NavigationStack {
        IncomeEditorView(existing: src)
    }
    .modelContainer(container)
}
