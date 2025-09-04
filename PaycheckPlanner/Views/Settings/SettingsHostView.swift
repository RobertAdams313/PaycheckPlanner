//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Updated on 9/3/25 – Removed all Back Up / Restore; lean host + Data Management (Reset only).
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsHostView: View {
    // Environment
    @Environment(\.modelContext) private var context

    // Persisted keys
    @AppStorage("planPeriodCount") private var planCount: Int = 4
    @AppStorage("appearance") private var appearance: String = "system"
    @AppStorage("defaultTab") private var defaultTabRaw: String = "plan"
    @AppStorage("billsGrouping") private var billsGrouping: String = "dueDate"
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("carryoverEnabled") private var carryoverEnabled: Bool = true
    @AppStorage("notifyBillsEnabled") private var notifyBillsEnabled: Bool = true
    @AppStorage("notifyIncomeEnabled") private var notifyIncomeEnabled: Bool = true

    var body: some View {
        List {
            // General
            Section {
                AppearanceSection(appearance: $appearance)
                DefaultTabSection(defaultTabRaw: $defaultTabRaw) // “Settings” removed
            } header: {
                Text("General")
            }

            // Configuration (navigation)
            Section {
                FullRowLinkRow(title: "App Behavior") {
                    AppBehaviorSettingsView(
                        planCount: $planCount,
                        billsGrouping: $billsGrouping,
                        carryoverEnabled: $carryoverEnabled,
                        hapticsEnabled: $hapticsEnabled
                    )
                }
                .accessibilityIdentifier("appBehaviorLink")

                FullRowLinkRow(title: "Data Management",
                               subtitle: "Reset Data") {
                    DataManagementView() // now only handles Reset Data
                }
                .accessibilityIdentifier("dataManagementLink")
            } header: {
                Text("Configuration")
            }

            // Notifications on main page
            Section {
                NotificationsSection(
                    notifyBillsEnabled: $notifyBillsEnabled,
                    notifyIncomeEnabled: $notifyIncomeEnabled
                )
            } header: {
                Text("Notifications")
            } footer: {
                Text("Adjust alert style in iOS Settings → Notifications → Paycheck Planner.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
    }
}

// MARK: - Subscreens (non-data-management)

/// App Behavior – planning/behavior knobs
private struct AppBehaviorSettingsView: View {
    @Binding var planCount: Int
    @Binding var billsGrouping: String
    @Binding var carryoverEnabled: Bool
    @Binding var hapticsEnabled: Bool

    private let groupings: [(label: String, key: String)] = [
        ("Due Date", "dueDate"),
        ("Category", "category")
    ]

    var body: some View {
        List {
            Section("Planning") {
                HStack(spacing: 12) {
                    Text("Future Periods")
                    Spacer(minLength: 8)
                    Stepper(value: $planCount, in: 1...12) {
                        Text("\(planCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .labelsHidden()
                    .accessibilityIdentifier("planCountStepper")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Bills Grouping")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Bills Grouping", selection: $billsGrouping) {
                        ForEach(groupings, id: \.key) { g in
                            Text(g.label).tag(g.key)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("billsGroupingPicker")
                }
            }

            Section("Behavior") {
                Toggle("Carry Over Remaining", isOn: $carryoverEnabled)
                    .accessibilityIdentifier("carryoverToggle")

                Toggle("Haptics", isOn: $hapticsEnabled)
                    .accessibilityIdentifier("hapticsToggle")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Behavior")
    }
}

// MARK: - Reusable Pieces

private struct AppearanceSection: View {
    @Binding var appearance: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance").font(.headline)
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("appearancePicker")
        }
        .padding(.vertical, 4)
    }
}

private struct DefaultTabSection: View {
    @Binding var defaultTabRaw: String
    // “Settings” intentionally removed
    private let tabs: [(label: String, key: String)] = [
        ("Plan", "plan"),
        ("Bills", "bills"),
        ("Income", "income"),
        ("Insights", "insights")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Tab").font(.headline)
            Picker("Default Tab", selection: $defaultTabRaw) {
                ForEach(tabs, id: \.key) { t in
                    Text(t.label).tag(t.key)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("defaultTabPicker")
        }
        .padding(.vertical, 4)
    }
}

private struct NotificationsSection: View {
    @Binding var notifyBillsEnabled: Bool
    @Binding var notifyIncomeEnabled: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Push Alerts").font(.headline)
            Toggle(isOn: $notifyBillsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bill Reminders")
                    Text("Due-date nudges and upcoming warnings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("notifyBillsToggle")
            Toggle(isOn: $notifyIncomeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Income Notifications")
                    Text("Payday arrivals and schedule changes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("notifyIncomeToggle")
        }
        .padding(.vertical, 4)
    }
}

/// Full-width tappable navigation row with optional subtitle and chevron.
private struct FullRowLinkRow<Destination: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }
}
