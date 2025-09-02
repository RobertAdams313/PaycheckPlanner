//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Updated on 9/2/25 – Card UI + Liquid Glass & iCloud Sync merged; CSV import persists; notification hooks.
//
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

struct SettingsHostView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var context

    // MARK: Existing
    @AppStorage("planPeriodCount") private var planCount: Int = 4
    /// Appearance key: "system" | "light" | "dark"
    @AppStorage("appearance") private var appearance: String = "system"

    // MARK: Behavior
    /// "plan" | "bills" | "income" | "insights" | "settings"
    @AppStorage("defaultTab") private var defaultTabRaw: String = "plan"
    /// "dueDate" | "category"
    @AppStorage("billsGrouping") private var billsGrouping: String = "dueDate"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("reducedMotion") private var reducedMotion: Bool = false

    // MARK: Finance/Data
    @AppStorage("carryoverEnabled") private var carryoverEnabled: Bool = true
    @AppStorage("enforceBillEndDates") private var enforceBillEndDates: Bool = true
    @AppStorage("creditCardTrackingEnabled") private var creditCardTrackingEnabled: Bool = false
    /// "donut" | "pie" | "bar"
    @AppStorage("insightsChartStyle") private var insightsChartStyle: String = "donut"
    /// "exact" | "nearestDollar"
    @AppStorage("roundingPref") private var roundingPref: String = "exact"

    // MARK: Notifications
    @AppStorage("paydayNotifications") private var paydayNotifications: Bool = false
    @AppStorage("billDueNotifications") private var billDueNotifications: Bool = false
    /// 1, 3, 7 days before
    @AppStorage("billReminderDays") private var billReminderDays: Int = 3

    // MARK: Liquid Glass + Sync (merged)
    @AppStorage("liquidGlassEnabled") private var liquidGlassEnabled: Bool = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @State private var showRelaunchAlert: Bool = false

    // MARK: Import/Help
    @State private var showCSVImporter = false
    @State private var showCSVHelp = false
    @State private var lastImportedFileName: String?
    @State private var importStatus: String?

    var body: some View {
        NavigationStack {
            List {
                // MARK: Plan
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Paychecks to show")
                                Spacer()
                                Stepper("", value: $planCount, in: 1...12)
                                    .labelsHidden()
                                Text("\(planCount)")
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 28, alignment: .trailing)
                            }
                            Text("Controls how many upcoming paychecks appear on the Plan and Insights tabs.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                } header: { Text("Plan") }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Appearance
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Theme", selection: $appearance) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)

                            HStack {
                                Text("Insights chart style")
                                Spacer()
                                Picker("", selection: $insightsChartStyle) {
                                    Text("Donut").tag("donut")
                                    Text("Pie").tag("pie")
                                    Text("Bar").tag("bar")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            Toggle(isOn: $liquidGlassEnabled) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Liquid Glass")
                                    Text(isLiquidGlassAvailable
                                         ? "Animated glass background"
                                         : "Requires newer iOS")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(!isLiquidGlassAvailable)

                            Toggle("Reduce motion", isOn: $reducedMotion)
                            Text("Reduces certain animations and chart transitions.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                } header: { Text("Appearance") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: App Behavior
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Default tab on launch")
                                Spacer()
                                Picker("", selection: $defaultTabRaw) {
                                    Text("Plan").tag("plan")
                                    Text("Bills").tag("bills")
                                    Text("Income").tag("income")
                                    Text("Insights").tag("insights")
                                    Text("Settings").tag("settings")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            HStack {
                                Text("Bills list default grouping")
                                Spacer()
                                Picker("", selection: $billsGrouping) {
                                    Text("By Due Date").tag("dueDate")
                                    Text("By Category").tag("category")
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            Toggle("Haptic feedback", isOn: $hapticsEnabled)

                            Text("You can still switch groupings on the Bills tab. Default tab sets where the app opens.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                } header: { Text("App Behavior") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Finance
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Carry over remaining balance to the next pay period", isOn: $carryoverEnabled)

                            Toggle("Enforce bill end dates", isOn: $enforceBillEndDates)
                            Text("Bills stop generating after their configured end date and won’t appear before their anchor date.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Picker("Rounding", selection: $roundingPref) {
                                Text("Exact cents").tag("exact")
                                Text("Nearest dollar").tag("nearestDollar")
                            }
                            .pickerStyle(.segmented)

                            Toggle("Credit card tracking", isOn: $creditCardTrackingEnabled)
                            Text("Enable storing card balances and APR for payoff planning.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                } header: { Text("Finance") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Notifications
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Payday notifications", isOn: $paydayNotifications)
                                .onChange(of: paydayNotifications) { on in
                                    if on {
                                        NotificationScheduler.requestAuthorizationIfNeeded()
                                        // TODO: schedule upcoming payday notifications
                                    } else {
                                        NotificationScheduler.removeAllScheduled(matching: "payday_")
                                    }
                                }
                            Toggle("Bill due reminders", isOn: $billDueNotifications)
                                .onChange(of: billDueNotifications) { on in
                                    if on {
                                        NotificationScheduler.requestAuthorizationIfNeeded()
                                        // TODO: schedule upcoming bill due reminders using billReminderDays
                                    } else {
                                        NotificationScheduler.removeAllScheduled(matching: "billdue_")
                                    }
                                }

                            HStack {
                                Text("Remind me")
                                Spacer()
                                Picker("", selection: $billReminderDays) {
                                    Text("1 day before").tag(1)
                                    Text("3 days before").tag(3)
                                    Text("1 week before").tag(7)
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .disabled(!billDueNotifications)
                            }

                            Text("You’ll be prompted to allow notifications the first time you enable these.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                } header: { Text("Notifications") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Sync (merged)
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("iCloud Sync", isOn: Binding(
                                get: { iCloudSyncEnabled },
                                set: { newValue in
                                    iCloudSyncEnabled = newValue
                                    // Container is chosen at Scene creation → relaunch required.
                                    showRelaunchAlert = true
                                }
                            ))
                            .alert("Relaunch Required",
                                   isPresented: $showRelaunchAlert) {
                                Button("OK") { }
                            } message: {
                                Text("Quit and relaunch the app to apply the iCloud sync setting.")
                            }
                        }
                        .padding(12)
                    }
                } header: { Text("Sync") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Import & Export
                Section {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                showCSVImporter = true
                            } label: {
                                HStack {
                                    Label("Import CSV", systemImage: "tray.and.arrow.down")
                                    Spacer()
                                }
                            }

                            Button {
                                showCSVHelp = true
                            } label: {
                                HStack {
                                    Label("Learn more", systemImage: "questionmark.circle")
                                    Spacer()
                                }
                            }

                            if let name = lastImportedFileName {
                                HStack {
                                    Text("Last imported")
                                    Spacer()
                                    Text(name).foregroundStyle(.secondary)
                                }
                            }
                            if let importStatus {
                                Text(importStatus)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Use a simple template with columns like Name, Amount, Category, Due Date. You can also export data from the Plan or Bills tabs (coming soon).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                } header: { Text("Import & Export") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)

                // MARK: Data
                Section {
                    CardContainer {
                        VStack(spacing: 8) {
                            NavigationLink {
                                ResetDataView()
                            } label: {
                                HStack {
                                    Text("Reset data")
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                            }
                            Text("This cannot be undone. Consider exporting a backup first.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(12)
                    }
                } header: { Text("Data") }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)  // Let cards contrast with the app’s background.
            .background(Color.clear)
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.text, UTType.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    lastImportedFileName = url.lastPathComponent
                    Task { await importCSV(at: url) }
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $showCSVHelp) { CSVHelpSheet() }
        }
    }

    // MARK: - Helpers

    private var isLiquidGlassAvailable: Bool {
        if #available(iOS 18, *) { return true } else { return false }
    }

    // CSV import → parse off-main → insert into SwiftData → save
    @MainActor
    private func importCSV(at url: URL) async {
        do {
            let rows = try await parseRows(url: url)
            var inserted = 0
            for row in rows {
                let rec = BillRecurrence(rawValue: (row.recurrence ?? "once").lowercased()) ?? .once
                let bill = Bill(
                    name: row.name,
                    amount: row.amount,
                    recurrence: rec,
                    anchorDueDate: row.dueDate,
                    category: row.category
                )
                context.insert(bill)
                inserted += 1
            }
            try context.save()
            Haptics.success()
            importStatus = "Imported \(inserted) bills."
        } catch {
            Haptics.error()
            importStatus = "Import failed: \(error.localizedDescription)"
        }
    }

    private func parseRows(url: URL) async throws -> [CSVBillRow] {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do { cont.resume(returning: try CSVImporter.parseBills(from: url)) }
                catch { cont.resume(throwing: error) }
            }
        }
    }
}

// MARK: - Inline Help Sheet (unchanged)
private struct CSVHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let example = """
Name,Amount,Category,DueDate,Recurrence,EndDate,Notes
"Rent",1500.00,Housing,2025-09-05,monthly,,Optional note
"Internet",75.00,Utilities,2025-09-10,monthly,,
"Gym",29.99,Health,2025-09-12,monthly,2026-09-12,Annual promo
"Car Insurance",120.00,Auto,2025-09-15,monthly,,
"""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CSV Import Template")
                        .font(.title3).bold()
                    Text("""
Include a header row with these columns:

• Name (String)
• Amount (Decimal, e.g., 120.00)
• Category (String)
• DueDate (YYYY-MM-DD)
• Recurrence (once|weekly|biweekly|semimonthly|monthly)
• EndDate (optional, YYYY-MM-DD)
• Notes (optional)

Dates should be in your local timezone. Unknown or blank values will be skipped safely.
""")

                    GroupBox("Example") {
                        ScrollView(.horizontal) {
                            Text(example)
                                .font(.system(.footnote, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(.vertical, 8)
                        }
                    }

                    Text("Tips")
                        .font(.headline)
                    Text("""
• Large imports parse off the main thread to avoid UI hangs.
• You can re-import to update or add items; duplicates can be detected by (Name, Amount, DueDate).
• EndDate stops recurring bills and avoids generating items before their anchor date (if enabled in Settings).
""")
                }
                .padding()
            }
            .navigationTitle("Import Help")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reset View (unchanged)
private struct ResetDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var confirming = false
    @State private var didReset = false

    var body: some View {
        Form {
            Section {
                Button(role: .destructive) {
                    confirming = true
                } label: {
                    Label("Erase all local data", systemImage: "trash")
                }
            } footer: {
                Text("This cannot be undone. Consider exporting a backup first.")
            }
        }
        .navigationTitle("Reset Data")
        .alert("Erase all data?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) { }
            Button("Erase", role: .destructive) {
                // TODO: Implement your actual purge logic using SwiftData context
                // try? context.delete(model:) / fetch & delete
                didReset = true
                dismiss()
            }
        } message: {
            Text("All Pay Schedules, Incomes, and Bills will be removed from this device.")
        }
    }
}

// MARK: - Card Container (shared look)
private struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12))
            )
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}
