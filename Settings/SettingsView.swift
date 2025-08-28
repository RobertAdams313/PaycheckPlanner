//
//  SettingsView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

struct SettingsView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appThemeRaw) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Sync")) {
                    Toggle("Sync with iCloud", isOn: $iCloudSyncEnabled)
                    Text("Changing this requires an app relaunch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(footer: Text("Version 1.0 • Paycheck Planner")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }
}
