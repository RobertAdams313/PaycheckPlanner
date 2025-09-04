//
//  DataManagementView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/3/25.
//  Purpose: Data Management screen – Reset Data only (Back Up / Restore removed).
//

import SwiftUI
import SwiftData

struct DataManagementView: View {
    @Environment(\.modelContext) private var context

    // Reset Data
    @State private var showResetConfirm = false
    @State private var resetAlert: (title: String, message: String)? = nil

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash.circle")
                        Text("Reset All Data (Bills & Income)")
                        Spacer()
                    }
                }
                .accessibilityIdentifier("resetAllDataButton")
            } footer: {
                Text("This deletes all bills and incomes. App settings are unaffected.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Management")
        .confirmationDialog("Reset All Data", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Delete Bills & Incomes", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all bills and incomes. It cannot be undone.")
        }
        .alert(resetAlert?.title ?? "", isPresented: Binding(
            get: { resetAlert != nil },
            set: { if !$0 { resetAlert = nil } })
        ) {
            Button("OK", role: .cancel) { resetAlert = nil }
        } message: {
            Text(resetAlert?.message ?? "")
        }
    }

    // MARK: - Reset All Data (Bills & Income only)

    private func resetAllData() {
        do {
            try deleteAll(of: Bill.self)
            try deleteAll(of: IncomeSchedule.self)
            try context.save()
            resetAlert = ("Reset Complete", "All bills and incomes have been deleted.")
        } catch {
            resetAlert = ("Reset Failed", error.localizedDescription)
        }
    }

    private func deleteAll<T: PersistentModel>(of type: T.Type) throws {
        let fetch = FetchDescriptor<T>()
        let items = try context.fetch(fetch)
        for i in items { context.delete(i) }
    }
}
