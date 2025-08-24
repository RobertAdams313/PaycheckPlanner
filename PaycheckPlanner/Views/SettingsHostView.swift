//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI

/// Central Settings screen used by the Settings tab.
struct SettingsHostView: View {
    // How many upcoming paychecks to show on the Plan tab (default 4)
    @AppStorage("planPeriodCount") private var planCount: Int = 4

    // Use a stable AppStorage-backed value, then map to AppTheme.
    @AppStorage(AppTheme.storageKey) private var themeModeRaw: Int = AppTheme.system.rawValue
    private var themeBinding: Binding<AppTheme> {
        Binding<AppTheme>(
            get: { AppTheme(rawValue: themeModeRaw) ?? .system },
            set: { themeModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    Stepper(value: $planCount, in: 1...12) {
                        HStack {
                            Text("Paychecks to show")
                            Spacer()
                            Text("\(planCount)").foregroundStyle(.secondary)
                        }
                    }
                    Text("Controls how many upcoming paychecks appear on the Plan tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Appearance") {
                    Picker("Theme", selection: themeBinding) {
                        ForEach(AppTheme.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Applies immediately and you’ll stay on this page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
