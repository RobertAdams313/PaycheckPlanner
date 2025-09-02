//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Updated on 9/1/25
//

import SwiftUI
import SwiftData

struct SettingsHostView: View {
    @AppStorage("planPeriodCount") private var planCount: Int = 4
    // Appearance key you’ve been using: "system" | "light" | "dark"
    @AppStorage("appearance") private var appearance: String = "system"

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Plan
                Section("Plan") {
                    Stepper(value: $planCount, in: 1...12) {
                        Text("Paychecks to show")
                        Spacer()
                        Text("\(planCount)").foregroundStyle(.secondary)
                    }
                    Text("Controls how many upcoming paychecks appear on the Plan and Insights tabs.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // MARK: Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Data (renders its own Section internally)
                SettingsDataStoreSection()

                // MARK: About
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
