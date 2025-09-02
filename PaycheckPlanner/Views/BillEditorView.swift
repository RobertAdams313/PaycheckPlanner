//
//  BillEditorView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Currency field clears placeholder on focus + auto-commits on blur
//                         Adds optional Recurrence End Date with validation (builds off user file)
//

import SwiftUI
import SwiftData

/// Create or edit a Bill. Uses a real currency field and saves into SwiftData.
struct BillEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Existing bill if editing
    let existingBill: Bill?

    // Inputs
    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var dueDate: Date = .now
    @State private var recurrence: BillRecurrence = .monthly
    @State private var category: String = ""

    // NEW: Recurrence end date
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = .now

    // UI
    @FocusState private var amountFocused: Bool
    @State private var showSaveError = false
    @State private var errorMessage = ""

    /// Called after a successful save or delete (optional hook for parent)
    var onComplete: (Bool) -> Void = { _ in }

    // MARK: - Init
    init(existingBill: Bill? = nil, onComplete: @escaping (Bool) -> Void = { _ in }) {
        self.existingBill = existingBill
        self.onComplete = onComplete
    }

    // MARK: - Body
    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                    .modifier(NameAutoCapModifier(text: $name))

                // Currency field with placeholder-clear on focus + auto-commit on blur
                CurrencyField("Amount", value: $amount, focused: $amountFocused)

                Picker("Recurrence", selection: $recurrence) {
                    ForEach(BillRecurrence.allCases) { r in
                        Text(title(for: r)).tag(r)
                    }
                }

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .help("Anchor date used with the recurrence to compute occurrences.")

                // NEW: End date controls
                Toggle("Has End Date", isOn: $hasEndDate.animation())

                if hasEndDate {
                    DatePicker("End Date", selection: $endDate, in: dueDate... , displayedComponents: .date)
                        .onChange(of: dueDate) { _, newDue in
                            if endDate < newDue { endDate = newDue }
                        }
                        .accessibilityHint("No bill occurrences will be generated after this date.")

                    if !endDateIsValid {
                        Text("End Date cannot be before Due Date.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("EndDateValidationText")
                    }
                }
            }

            Section("Category") {
                TextField("Category (optional)", text: $category)
                    .modifier(NameAutoCapModifier(text: $category))
            }

            if existingBill != nil {
                Section {
                    Button(role: .destructive) { deleteBill() } label: {
                        Label("Delete Bill", systemImage: "trash")
                    }
                }
            }

            if showSaveError {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("BillEditorErrorText")
                }
            }
        }
        .navigationTitle(existingBill == nil ? "New Bill" : "Edit Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveBill() }
                    .disabled(!isValid)
                    .bold()
            }
            // Uses the same focus binding the CurrencyField gets
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { amountFocused = false }
            }
        }
        .onAppear(perform: loadIfEditing)
    }

    // MARK: - Validation
    private var isValid: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let amountOK = amount > 0
        let endOK = !hasEndDate || endDateIsValid
        return hasName && amountOK && endOK
    }

    private var endDateIsValid: Bool {
        // When enabled, endDate must be >= dueDate (inclusive)
        !hasEndDate || endDate >= Calendar.current.startOfDay(for: dueDate)
    }

    private func title(for r: BillRecurrence) -> String {
        switch r {
        case .once: "One-time"
        case .weekly: "Weekly"
        case .biweekly: "Biweekly"
        case .semimonthly: "Twice a Month"
        case .monthly: "Monthly"
        }
    }

    // MARK: - Lifecycle
    private func loadIfEditing() {
        guard let b = existingBill else {
            // Initialize sensible defaults for a new bill
            dueDate = Calendar.current.startOfDay(for: dueDate)
            endDate = dueDate
            return
        }
        name = b.name
        amount = b.amount
        recurrence = b.recurrence
        dueDate = b.anchorDueDate
        category = b.category

        // NEW: hydrate end date
        if let e = b.endDate {
            hasEndDate = true
            endDate = max(Calendar.current.startOfDay(for: dueDate), e)
        } else {
            hasEndDate = false
            endDate = Calendar.current.startOfDay(for: dueDate)
        }
    }

    // MARK: - Actions
    private func saveBill() {
        guard isValid else { return }

        do {
            if let b = existingBill {
                // Edit in place
                b.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                b.amount = amount
                b.recurrence = recurrence
                b.anchorDueDate = Calendar.current.startOfDay(for: dueDate)
                b.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
                // NEW: persist end date
                b.endDate = hasEndDate ? Calendar.current.startOfDay(for: endDate) : nil
            } else {
                // Create
                let b = Bill(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    amount: amount,
                    recurrence: recurrence,
                    anchorDueDate: Calendar.current.startOfDay(for: dueDate),
                    category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                    endDate: hasEndDate ? Calendar.current.startOfDay(for: endDate) : nil,
                    active: true
                )
                context.insert(b)
            }

            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    private func deleteBill() {
        guard let b = existingBill else { return }
        do {
            context.delete(b)
            try context.save()
            onComplete(true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}

//
// MARK: - CurrencyField (unchanged behavior; builds on your implementation)
//

/// A localized currency field that binds a Decimal while:
/// - Showing a localized currency placeholder (e.g. "$0.00")
/// - Clearing placeholder on focus if value is zero
/// - Auto-committing and reformatting on blur
fileprivate struct CurrencyField: View {
    let title: String
    @Binding var value: Decimal

    // Bind to parent focus so the keyboard "Done" in the parent works.
    var focused: FocusState<Bool>.Binding

    @State private var text: String = ""

    // Shared formatter
    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    private var placeholderCurrency: String {
        CurrencyField.fmt.string(from: 0) ?? "0.00"
    }

    init(_ title: String, value: Binding<Decimal>, focused: FocusState<Bool>.Binding) {
        self.title = title
        _value = value
        self.focused = focused
        // Initialize text to a properly formatted string
        _text = State(initialValue: CurrencyField.fmt.string(from: NSDecimalNumber(decimal: value.wrappedValue)) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholderCurrency, text: $text)
                .keyboardType(.decimalPad)
                .focused(focused)
                .submitLabel(.done)
                .onChange(of: focused.wrappedValue) { isFocused in
                    if isFocused {
                        // Clear placeholder only if we were showing it / value is zero.
                        if value == 0 || text == placeholderCurrency || text.isEmpty {
                            text = ""
                        }
                    } else {
                        // On blur: if empty, treat as zero; then commit & reformat
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            text = "0"
                        }
                        commit()
                    }
                }
                .onChange(of: text) { _ in
                    // Live-parse for a responsive feel but allow partials
                    value = parseDecimal(from: text) ?? value
                }
                .onAppear {
                    // On appear, present placeholder for zero; otherwise formatted value
                    if value == 0 {
                        text = placeholderCurrency
                    } else {
                        text = CurrencyField.fmt.string(from: NSDecimalNumber(decimal: value)) ?? ""
                    }
                }
                .onSubmit { commit() }
                .accessibilityIdentifier("CurrencyTextField")
        }
        .padding(.vertical, 4)
    }

    private func commit() {
        let dec = parseDecimal(from: text) ?? value
        value = dec
        text = CurrencyField.fmt.string(from: NSDecimalNumber(decimal: dec)) ?? ""
    }

    /// Simple, locale-tolerant numeric parse: allow digits and one decimal separator.
    private func parseDecimal(from s: String) -> Decimal? {
        let _ = Locale.current.decimalSeparator ?? "."
        // Normalize any commas to dot for parsing, but keep user typing flexible
        let normalized = s
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.".contains($0) }

        if normalized.isEmpty { return 0 }
        return Decimal(string: normalized)
    }
}
