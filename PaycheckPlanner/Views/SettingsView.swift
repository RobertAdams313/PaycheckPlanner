//
//  SettingsView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI

/// Full replacement SettingsView with:
/// - Liquid Glass toggle (iOS 26+ only)
/// - Theme picker (System / Light / Dark)
/// - iCloud Sync toggle (preference only; relaunch required to apply)
struct SettingsView: View {
    // Appearance
    @AppStorage(kLiquidGlassEnabledKey) private var liquidGlassEnabled: Bool = true
    @AppStorage("appTheme") private var appThemeRaw: String = "system" // "system" | "light" | "dark"

    // Sync
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = false
    @State private var showRelaunchAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // === APPEARANCE ===
                Section("Appearance") {
                    Toggle(isOn: $liquidGlassEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Liquid Glass (iOS 26+)")
                            Text(isLiquidGlassAvailable
                                 ? "Animated glass background"
                                 : "Requires iOS 26+")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!isLiquidGlassAvailable)

                    Picker("Theme", selection: $appThemeRaw) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                }

                // === SYNC ===
                Section("Sync") {
                    Toggle("iCloud Sync", isOn: Binding(
                        get: { iCloudSyncEnabled },
                        set: { newValue in
                            iCloudSyncEnabled = newValue
                            // Because the container is chosen at Scene creation time,
                            // a relaunch is required to switch between local/CloudKit.
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

                // === YOUR OTHER SETTINGS (re-add below) ===
                // Section { ... }
            }
            .navigationTitle("Settings")
        }
    }

    private var isLiquidGlassAvailable: Bool {
        if #available(iOS 26, *) { return true } else { return false }
    }
}
