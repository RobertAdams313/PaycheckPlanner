//
//  SettingsDataStoreSection.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  SettingsDataStoreSection.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/1/25
//

import SwiftUI
import SwiftData

/// A reusable Settings section for data-store actions (export, reset, etc.)
struct SettingsDataStoreSection: View {
    @Environment(\.modelContext) private var context

    /// Optional callback that the host can use after destructive actions
    var onAfterReset: (() -> Void)?

    // UI state
    @State private var isResetting = false
    @State private var showConfirmWipe = false
    @State private var lastError: String?

    var body: some View {
        Section("Data") {
            Button {
                showConfirmWipe = true
            } label: {
                Label("Erase All Data", systemImage: "trash")
            }
            .tint(.red)

            if let lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog(
            "Erase all app data?",
            isPresented: $showConfirmWipe,
            titleVisibility: .visible
        ) {
            Button("Erase Everything", role: .destructive) {
                Task { await wipeAllData() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete all locally stored income sources/schedules, bills, and related data.")
        }
    }

    // MARK: - Actions

    @MainActor
    private func wipeAllData() async {
        guard !isResetting else { return }
        isResetting = true
        defer { isResetting = false }

        do {
            try deleteAll(IncomeSource.self)
            try deleteAll(IncomeSchedule.self)
            try deleteAll(Bill.self)
            try deleteAll(PaySchedule.self)

            try context.save()
            lastError = nil
            onAfterReset?()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    private func deleteAll<M>(_ type: M.Type) throws where M: PersistentModel {
        let descriptor = FetchDescriptor<M>()
        let all = try context.fetch(descriptor)
        for obj in all { context.delete(obj) }
    }
}
