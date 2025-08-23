import SwiftUI
import SwiftData

struct AddOrEditBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var recurrence: BillRecurrence = .monthly
    @State private var anchorDueDate: Date = .now
    @State private var recurrenceEnd: Date? = nil
    @State private var useEndDate: Bool = false
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill") {
                    TextField("Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).keyboardType(.decimalPad)
                    Picker("Repeats", selection: $recurrence) { ForEach(BillRecurrence.allCases) { r in Text(r.displayName).tag(r) } }
                    DatePicker(recurrence == .once ? "Due date" : "Anchor date", selection: $anchorDueDate, displayedComponents: [.date])
                    Toggle("Set end date", isOn: $useEndDate.animation())
                    if useEndDate {
                        DatePicker("End by", selection: Binding(get: { recurrenceEnd ?? Date.now }, set: { recurrenceEnd = $0 }), displayedComponents: [.date])
                    }
                }
                Section("Notes") { TextField("Optional", text: $notes, axis: .vertical) }
            }
            .navigationTitle("Add Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0) }
            }
        }
    }
    private func save() {
        let bill = Bill(name: name.trimmingCharacters(in: .whitespaces), amount: amount, recurrence: recurrence, anchorDueDate: anchorDueDate, recurrenceEnd: useEndDate ? recurrenceEnd : nil, notes: notes.isEmpty ? nil : notes)
        context.insert(bill); dismiss()
    }
}
