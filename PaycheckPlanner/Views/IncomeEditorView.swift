//
//  IncomeEditorView.swift
//  PaycheckPlanner
//
//  Updated on 9/3/25 – iOS 17-safe focus change handling (no deprecated onChange),
//                       amount clears on focus & commits on blur/other-control.
//                       Delete confirmation preserved.
//  Updated on 9/3/25 (fix): Switch to local DRAFT editing (no live mutations).
//                           Cancel truly discards edits; Save applies to SwiftData.
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
    f.locale = .current
    return f.string(from: n) ?? "$0.00"
}

private func parseDecimal(from s: String) -> Decimal {
    // Accept digits and one dot/comma; simple, locale-tolerant parse.
    let dec = s
        .replacingOccurrences(of: ",", with: ".")
        .filter { "0123456789.".contains($0) }
    return Decimal(string: dec) ?? 0
}

// MARK: - Draft models (local-only, not persisted)

private struct DraftSchedule {
    var hasSchedule: Bool
    var frequency: PayFrequency
    var anchorDate: Date
    var firstDay: Int
    var secondDay: Int
}

struct IncomeEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // We read from this model and write back ONLY on Save.
    let source: IncomeSource

    // MARK: - Draft state (no live mutations)
    @State private var draftName: String = ""
    @State private var draftVariable: Bool = false

    // Currency field uses a string for editing UX; we keep both text + parsed number.
    @State private var draftAmountText: String = ""
    @State private var draftAmount: Decimal = 0
    @FocusState private var amountFocused: Bool

    @State private var draftSchedule = DraftSchedule(
        hasSchedule: false,
        frequency: .biweekly,
        anchorDate: Date(),
        firstDay: 1,
        secondDay: 15
    )

    // UI
    @State private var showDeleteConfirm = false

    // MARK: - Init

    init(existing: IncomeSource) {
        self.source = existing
    }

    // MARK: - View

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                // Currency editor (String-backed)
                TextField("Default amount", text: $draftAmountText, prompt: Text("$0.00"))
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .submitLabel(.done)
                    .onFocusChangeCompat($amountFocused) { _, focused in
                        if focused {
                            // Clear placeholder when focusing an empty/zero value
                            if draftAmount == 0,
                               draftAmountText.isEmpty || draftAmountText == ppFormatCurrency(0) {
                                draftAmountText = ""
                            }
                        } else {
                            commitAmount() // auto-commit on blur
                        }
                    }
                    .onSubmit { commitAmount() }

                Toggle("Variable amount", isOn: $draftVariable)
                    .onTapGesture { amountFocused = false } // finalize before toggling
            }

            Section("Schedule") {
                // Frequency
                Picker("Frequency", selection: $draftSchedule.frequency) {
                    Text("One-time").tag(PayFrequency.once)
                    Text("Weekly").tag(PayFrequency.weekly)
                    Text("Bi-weekly").tag(PayFrequency.biweekly)
                    Text("Semi-monthly").tag(PayFrequency.semimonthly)
                    Text("Monthly").tag(PayFrequency.monthly)
                }
                .onTapGesture { amountFocused = false }

                // Start date
                DatePicker("Starts", selection: $draftSchedule.anchorDate, displayedComponents: .date)
                    .onTapGesture { amountFocused = false }

                // Semi-monthly details when applicable
                if draftSchedule.frequency == .semimonthly {
                    Stepper(value: $draftSchedule.firstDay, in: 1...28) {
                        Text("First day: \(draftSchedule.firstDay)")
                    }
                    .onTapGesture { amountFocused = false }

                    Stepper(value: $draftSchedule.secondDay, in: 1...28) {
                        Text("Second day: \(draftSchedule.secondDay)")
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
        .navigationTitle(draftName.isEmpty ? "Income" : draftName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadDraft)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    amountFocused = false
                    // No writes to model: drafts are discarded.
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    amountFocused = false
                    commitAmount()
                    applyDraftAndSave()
                    dismiss()
                }
                .bold()
                .disabled(!isValid)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .alert("Delete this income?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the income source\(source.schedule != nil ? " and its schedule" : ""). This action cannot be undone.")
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && draftAmount > 0
    }

    // MARK: - Draft lifecycle

    private func loadDraft() {
        draftName = source.name
        draftVariable = source.variable
        draftAmount = source.defaultAmount
        draftAmountText = (draftAmount == 0) ? "" : ppFormatCurrency(draftAmount)

        if let s = source.schedule {
            draftSchedule = DraftSchedule(
                hasSchedule: true,
                frequency: s.frequency,
                anchorDate: s.anchorDate,
                firstDay: s.semimonthlyFirstDay,
                secondDay: s.semimonthlySecondDay
            )
        } else {
            draftSchedule = DraftSchedule(
                hasSchedule: false,
                frequency: .biweekly,
                anchorDate: Date(),
                firstDay: 1,
                secondDay: 15
            )
        }
    }

    // MARK: - Actions

    /// Confirm/commit the `draftAmountText` into `draftAmount`, and reformat the field.
    private func commitAmount() {
        let newValue = parseDecimal(from: draftAmountText)
        draftAmount = newValue
        draftAmountText = (newValue == 0) ? "" : ppFormatCurrency(newValue)
    }

    /// Apply draft values to the SwiftData model and save.
    private func applyDraftAndSave() {
        source.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        source.variable = draftVariable
        source.defaultAmount = draftAmount

        // Schedule: create or update the model object to match the draft
        if let sched = source.schedule {
            // Update existing schedule
            sched.frequency = draftSchedule.frequency
            sched.anchorDate = draftSchedule.anchorDate
            sched.semimonthlyFirstDay = draftSchedule.firstDay
            sched.semimonthlySecondDay = draftSchedule.secondDay
        } else {
            // Create if not present (we always show schedule UI)
            let s = IncomeSchedule(
                source: source,
                frequency: draftSchedule.frequency,
                anchorDate: draftSchedule.anchorDate
            )
            s.semimonthlyFirstDay = draftSchedule.firstDay
            s.semimonthlySecondDay = draftSchedule.secondDay
            source.schedule = s
        }

        do { try context.save() } catch {
            // Non-fatal: you can surface an error UI if you prefer
            // For now, silently fail to keep UX smooth.
        }
    }

    private func performDelete() {
        if let s = source.schedule { context.delete(s) }
        context.delete(source)
        do { try context.save() } catch { /* non-fatal */ }
        dismiss()
    }
}

// MARK: - iOS 17 focus-change compatibility (Bool FocusState)

private struct FocusChangeCompatModifier: ViewModifier {
    var focused: FocusState<Bool>.Binding
    let action: (_ old: Bool, _ new: Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: focused.wrappedValue) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            content.onChange(of: focused.wrappedValue) { newValue in
                action(focused.wrappedValue, newValue)
            }
        }
    }
}

private extension View {
    /// Use this for FocusState<Bool>.Binding to avoid the deprecated one-parameter onChange
    /// and compiler crashes that sometimes occur with projectedValue generics.
    func onFocusChangeCompat(
        _ focused: FocusState<Bool>.Binding,
        perform: @escaping (_ old: Bool, _ new: Bool) -> Void
    ) -> some View {
        modifier(FocusChangeCompatModifier(focused: focused, action: perform))
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
