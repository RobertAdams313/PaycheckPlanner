//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct SettingsHostView: View {
    @AppStorage("planPeriodCount") private var planCount: Int = 4
    @AppStorage("themeMode") private var themeMode: Int = 0 // 0 system, 1 light, 2 dark

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    Stepper(value: $planCount, in: 1...12) {
                        Text("Paychecks to show")
                        Spacer()
                        Text("\(planCount)").foregroundStyle(.secondary)
                    }
                    Text("Controls how many upcoming paychecks appear on the Plan tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $themeMode) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
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
