import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.name) private var sources: [IncomeSource]

    @State private var showAdd = false
    @State private var edit: IncomeSource?

    var body: some View {
        List {
            ForEach(sources) { src in
                Button { edit = src } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(src.name)
                            if let n = src.notes, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(formatCurrency(src.defaultAmount)).bold().monospacedDigit()
                        Toggle("", isOn: Binding(get: { src.isActive }, set: { src.isActive = $0 })).labelsHidden()
                    }
                }
            }.onDelete { idx in idx.map { sources[$0] }.forEach { context.delete($0) } }
        }
        .navigationTitle("Income Sources")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Label("Add", systemImage: "plus.circle.fill") } } }
        .sheet(isPresented: $showAdd) { AddOrEditIncomeView(existing: nil) }
        .sheet(item: $edit) { src in AddOrEditIncomeView(existing: src) }
    }
}

struct AddOrEditIncomeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var existing: IncomeSource?

    @State private var name: String = ""
    @State private var amount: Decimal = 0
    @State private var notes: String = ""
    @State private var isActive: Bool = true

    init(existing: IncomeSource?) {
        self.existing = existing
        if let e = existing {
            _name = State(initialValue: e.name); _amount = State(initialValue: e.defaultAmount)
            _notes = State(initialValue: e.notes ?? ""); _isActive = State(initialValue: e.isActive)
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Default amount", value: $amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).keyboardType(.decimalPad)
                Toggle("Active", isOn: $isActive)
                TextField("Notes", text: $notes, axis: .vertical)
            }
            .navigationTitle(existing == nil ? "Add Income" : "Edit Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
        }
    }
    private func save() {
        if let e = existing {
            e.name = name.trimmingCharacters(in: .whitespaces); e.defaultAmount = amount; e.notes = notes.isEmpty ? nil : notes; e.isActive = isActive
        } else {
            let s = IncomeSource(name: name.trimmingCharacters(in: .whitespaces), defaultAmount: amount, isActive: isActive, notes: notes.isEmpty ? nil : notes)
            context.insert(s)
        }
        dismiss()
    }
}
