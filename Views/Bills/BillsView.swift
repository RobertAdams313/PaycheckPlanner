//
//  BillsView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct BillsView: View {
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @Environment(\.modelContext) private var context

    @State private var showingNewBill = false
    // Use Double for amount and **string token** for repeatFrequency ("one-time", "weekly", etc.)
    @State private var newBill: Bill = Bill(
        name: "",
        amount: 0.0,
        dueDate: .now,
        repeatFrequency: "one-time",
        category: "General",
        isPaid: false
    )

    var body: some View {
        List {
            Section("Upcoming") {
                ForEach(bills, id: \.id) { bill in
                    NavigationLink {
                        // If you use a bound editor elsewhere, keep it:
                        BillEditorView(bill: bill)
                    } label: {
                        billRow(bill)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    resetNewBill()
                    showingNewBill = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingNewBill) {
            NavigationStack {
                NewBillForm(
                    name: "",
                    amountString: "",
                    dueDate: .now,
                    repeatFrequency: "monthly",
                    category: "General"
                ) { created in
                    context.insert(created)
                    showingNewBill = false
                } onCancel: {
                    showingNewBill = false
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func billRow(_ bill: Bill) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.headline)
                Text(bill.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(bill.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .font(.body)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func resetNewBill() {
        newBill = Bill(
            name: "",
            amount: 0.0,
            dueDate: .now,
            repeatFrequency: "one-time",
            category: "General",
            isPaid: false
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(bills[index])
        }
    }
}

// MARK: - New Bill Creator (kept separate to simplify type-checking)

private struct NewBillForm: View {
    @Environment(\.dismiss) private var dismiss

    @State var name: String
    @State var amountString: String
    @State var dueDate: Date
    @State var repeatFrequency: String
    @State var category: String

    let onSave: (Bill) -> Void
    let onCancel: () -> Void

    private let frequenciesDisplay: [(label: String, value: String)] = [
        ("One Time", "one-time"),
        ("Weekly", "weekly"),
        ("Biweekly", "biweekly"),
        ("Monthly", "monthly"),
        ("Yearly", "yearly")
    ]

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                TextField("Amount", text: $amountString)
                    .keyboardType(.decimalPad)
                    .onChange(of: amountString) { _, _ in
                        // keep as plain string; parse on Save
                    }

                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
            }

            Section("Repeat") {
                Picker("Frequency", selection: $repeatFrequency) {
                    ForEach(frequenciesDisplay, id: \.value) { item in
                        Text(item.label).tag(item.value)
                    }
                }
            }

            Section("Category") {
                TextField("Category", text: $category)
                    .textInputAutocapitalization(.words)
            }
        }
        .navigationTitle("New Bill")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let parsed = Double(amountString.filter { "0123456789.".contains($0) }) ?? 0.0
                    let bill = Bill(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        amount: parsed,
                        dueDate: dueDate,
                        repeatFrequency: repeatFrequency,
                        category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                        isPaid: false
                    )
                    onSave(bill)
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
