//
//  MigrationSheet.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  MigrationSheet.swift
//  PaycheckPlanner
//

import SwiftUI

struct MigrationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var direction: MigrationDirection = .localToCloud
    @State private var isRunning = false
    @State private var report: MigrationReport?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Direction") {
                    Picker("Move data", selection: $direction) {
                        ForEach(MigrationDirection.allCases) { dir in
                            Text(dir.title).tag(dir)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if let report {
                    Section("Result") {
                        LabeledContent("Income sources copied", value: "\(report.copiedIncomeSources)")
                        LabeledContent("Income schedules copied", value: "\(report.copiedIncomeSchedules)")
                        LabeledContent("Pay schedules copied", value: "\(report.copiedPaySchedules)")
                        if report.skippedDuplicates > 0 {
                            LabeledContent("Skipped (duplicates)", value: "\(report.skippedDuplicates)")
                        }
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        runMigration()
                    } label: {
                        if isRunning {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Label("Run Migration", systemImage: "arrow.left.arrow.right.circle.fill")
                                .font(.headline)
                        }
                    }
                    .disabled(isRunning)
                } footer: {
                    Text("Copies Income, Income Schedules, and Pay Schedules. Existing matching items in the destination are skipped.")
                }
            }
            .navigationTitle("Migrate Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func runMigration() {
        isRunning = true
        report = nil
        errorText = nil
        Task { @MainActor in
            do {
                let r = try DataMigrator.migrate(direction: direction)
                report = r
            } catch {
                errorText = error.localizedDescription
            }
            isRunning = false
        }
    }
}
