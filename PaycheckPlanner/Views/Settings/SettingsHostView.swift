//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Updated on 9/2/25
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsHostView: View {
    // Existing
    @AppStorage("planPeriodCount") private var planCount: Int = 4
    /// Appearance key you’ve been using: "system" | "light" | "dark"
    @AppStorage("appearance") private var appearance: String = "system"

    // New – Behavior
    /// "plan" | "bills" | "income" | "insights" | "settings" (stringly-typed so we don’t couple to MainTab directly)
    @AppStorage("defaultTab") private var defaultTabRaw: String = "plan"
    /// "dueDate" | "category"
    @AppStorage("billsGrouping") private var billsGrouping: String = "dueDate"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("reducedMotion") private var reducedMotion: Bool = false

    // New – Finance/Data
    @AppStorage("carryoverEnabled") private var carryoverEnabled: Bool = true
    @AppStorage("enforceBillEndDates") private var enforceBillEndDates: Bool = true
    @AppStorage("creditCardTrackingEnabled") private var creditCardTrackingEnabled: Bool = false
    /// "donut" | "pie" | "bar"
    @AppStorage("insightsChartStyle") private var insightsChartStyle: String = "donut"
    /// Optional: rounding preference
    /// "exact" | "nearestDollar"
    @AppStorage("roundingPref") private var roundingPref: String = "exact"

    // New – Notifications (you’ll wire into UNUserNotificationCenter elsewhere)
    @AppStorage("paydayNotifications") private var paydayNotifications: Bool = false
    @AppStorage("billDueNotifications") private var billDueNotifications: Bool = false
    /// 1, 3, 7 days before
    @AppStorage("billReminderDays") private var billReminderDays: Int = 3

    // New – Import/Export & Help
    @State private var showCSVImporter = false
    @State private var showCSVHelp = false
    @State private var lastImportedFileName: String?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Plan
                Section {
                    Stepper(value: $planCount, in: 1...12) {
                        HStack {
                            Text("Paychecks to show")
                            Spacer()
                            Text("\(planCount)").foregroundStyle(.secondary)
                        }
                    }
                    Text("Controls how many upcoming paychecks appear on the Plan and Insights tabs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Plan")
                }

                // MARK: Appearance
                Section {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)

                    Picker("Insights chart style", selection: $insightsChartStyle) {
                        Text("Donut").tag("donut")
                        Text("Pie").tag("pie")
                        Text("Bar").tag("bar")
                    }
                    .pickerStyle(.menu)

                    Toggle("Reduce motion", isOn: $reducedMotion)
                    Text("Reduces certain animations and chart transitions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Appearance")
                }

                // MARK: Behavior
                Section {
                    Picker("Default tab on launch", selection: $defaultTabRaw) {
                        Text("Plan").tag("plan")
                        Text("Bills").tag("bills")
                        Text("Income").tag("income")
                        Text("Insights").tag("insights")
                        Text("Settings").tag("settings")
                    }

                    Picker("Bills list default grouping", selection: $billsGrouping) {
                        Text("By Due Date").tag("dueDate")
                        Text("By Category").tag("category")
                    }

                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                } header: {
                    Text("App Behavior")
                } footer: {
                    Text("You can still switch groupings on the Bills tab. Default tab sets where the app opens.")
                }

                // MARK: Finance
                Section {
                    Toggle("Carry over leftover to next period", isOn: $carryoverEnabled)

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
                } header: {
                    Text("Finance")
                }

                // MARK: Notifications
                Section {
                    Toggle("Payday notifications", isOn: $paydayNotifications)
                    Toggle("Bill due reminders", isOn: $billDueNotifications)
                    Picker("Remind me", selection: $billReminderDays) {
                        Text("1 day before").tag(1)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                    }
                    .disabled(!billDueNotifications)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("You’ll be prompted to allow notifications the first time you enable these.")
                }

                // MARK: Import / Export
                Section {
                    Button {
                        showCSVImporter = true
                    } label: {
                        Label("Import CSV", systemImage: "tray.and.arrow.down")
                    }

                    Button {
                        showCSVHelp = true
                    } label: {
                        Label("Learn more", systemImage: "questionmark.circle")
                    }

                    if let name = lastImportedFileName {
                        HStack {
                            Text("Last imported")
                            Spacer()
                            Text(name).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Import & Export")
                } footer: {
                    Text("Use a simple template with columns like Name, Amount, Category, Due Date. You can also export data from the Plan or Bills tabs (coming soon).")
                }

                // MARK: Data Management
                Section {
                    NavigationLink {
                        ResetDataView()
                    } label: {
                        Text("Reset data")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Data")
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.text, UTType.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    lastImportedFileName = url.lastPathComponent
                    // Hand off to your CSV import pipeline:
                    // CSVImporter.shared.importBills(from: url)
                    // You can parse on a background thread to keep UI snappy.
                case .failure:
                    // No-op or set a status message if you track one
                    break
                }
            }
            .sheet(isPresented: $showCSVHelp) { CSVHelpSheet() }
        }
    }
}

// MARK: - Inline Help Sheet

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

// MARK: - Reset View (non-destructive showcase; wire your own reset)

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
