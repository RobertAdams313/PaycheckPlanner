//
//  BillEditorView.swift
//  PaycheckPlanner
//
//  Updated: iOS 17 onChange compatibility, keeps cancel-no-save behavior,
//  keeps CurrencyField, NameAutoCapModifier, End Date support & Delete.
//  Layout: Category moved directly under Has End Date inside the Details section.
//

import SwiftUI
import SwiftData

// Temporary: keep old name compiling while you migrate call sites.
typealias AddOrEditBillView = BillEditorView

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

    // Recurrence end date
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = .now

    // UI
    @FocusState private var amountFocused: Bool
    @State private var showSaveError = false
    @State private var errorMessage = ""

    /// Called after a successful save or delete (optional hook for parent)
    var onComplete: (Bool) -> Void = { _ in }

    init(existingBill: Bill? = nil, onComplete: @escaping (Bool) -> Void = { _ in }) {
        self.existingBill = existingBill
        self.onComplete = onComplete
    }

    var body: some View {
        Form {
            // MARK: - Details (Category now lives here, right under Has End Date)
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
                .onChangeCompat(of: $recurrence) { _, _ in commitFromOtherControl() }

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    .help("Anchor date used with the recurrence to compute occurrences.")
                    .onChangeCompat(of: $dueDate) { _, _ in commitFromOtherControl() }

                Toggle("Has End Date", isOn: $hasEndDate.animation())
                    .onChangeCompat(of: $hasEndDate) { _, _ in commitFromOtherControl() }

                if hasEndDate {
                    DatePicker("End Date", selection: $endDate, in: dueDate... , displayedComponents: .date)
                        .onChangeCompat(of: $endDate) { _, _ in commitFromOtherControl() }
                        .accessibilityHint("No bill occurrences will be generated after this date.")

                    if !endDateIsValid {
                        Text("End Date cannot be before Due Date.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("EndDateValidationText")
                    }
                }

                // --- Category moved here (same container/section) ---
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    CategoryPicker(category: $category)
                        .onTapGesture { commitFromOtherControl() }
                }
                .padding(.top, 2)
                // ----------------------------------------------------
            }

            // Delete (only when editing)
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
                Button("Cancel") { dismiss() } // never inserts on cancel
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveBill() }
                    .disabled(!isValid)
                    .bold()
            }
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
            let sod = Calendar.current.startOfDay(for: dueDate)
            dueDate = sod
            endDate = sod
            return
        }
        name = b.name
        amount = b.amount
        recurrence = b.recurrence
        dueDate = b.anchorDueDate
        category = b.category

        // End date (if your model has it)
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
                // Persist end date if your model supports it
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

    /// Treat switching to another control as "Done" for the amount field.
    private func commitFromOtherControl() {
        if amountFocused { amountFocused = false } // CurrencyField commits on blur
    }
}

// MARK: - CurrencyField (unchanged behavior)

fileprivate struct CurrencyField: View {
    let title: String
    @Binding var value: Decimal
    var focused: FocusState<Bool>.Binding
    @State private var text: String = ""

    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .current
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    private var placeholderCurrency: String {
        CurrencyField.fmt.string(from: NSNumber(value: 0)) ?? "$0.00"
    }

    init(_ title: String, value: Binding<Decimal>, focused: FocusState<Bool>.Binding) {
        self.title = title
        _value = value
        self.focused = focused
        _text = State(initialValue:
            CurrencyField.fmt.string(from: NSDecimalNumber(decimal: value.wrappedValue)) ?? ""
        )
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
                .onFocusChangeCompat(focused) { _, isFocused in
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
                .onChangeCompat(of: $text) { _, _ in
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
        text = CurrencyField.fmt.string(from: NSDecimalNumber(decimal: dec)) ?? placeholderCurrency
    }

    private func parseDecimal(from s: String) -> Decimal? {
        let normalized = s
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.".contains($0) }
        if normalized.isEmpty { return 0 }
        return Decimal(string: normalized)
    }
}

// MARK: - iOS 17 onChange compatibility

private struct OnChangeCompatModifier<Value>: ViewModifier where Value: Equatable {
    @Binding var value: Value
    let action: (_ old: Value, _ new: Value) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.onChange(of: value) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            content.onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}

private extension View {
    /// Use for state/binding values (Equatable) to be iOS 17-safe.
    func onChangeCompat<Value>(of binding: Binding<Value>, perform: @escaping (_ old: Value, _ new: Value) -> Void) -> some View where Value: Equatable {
        modifier(OnChangeCompatModifier(value: binding, action: perform))
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
    /// Use this for FocusState<Bool>.Binding to avoid compiler crashes with generics.
    func onFocusChangeCompat(
        _ focused: FocusState<Bool>.Binding,
        perform: @escaping (_ old: Bool, _ new: Bool) -> Void
    ) -> some View {
        modifier(FocusChangeCompatModifier(focused: focused, action: perform))
    }
}
