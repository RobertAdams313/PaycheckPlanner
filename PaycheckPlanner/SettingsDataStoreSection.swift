//
//  SettingsDataStoreSection.swift
//  PaycheckPlanner
//

import SwiftUI

struct SettingsDataStoreSection: View {
    @AppStorage("dataStoreChoice") private var choiceRaw: String = DataStoreChoice.iCloud.rawValue
    @State private var showMigration = false

    private var choice: DataStoreChoice {
        get { DataStoreChoice(rawValue: choiceRaw) ?? .iCloud }
        set { choiceRaw = newValue.rawValue }
    }

    var body: some View {
        Section("Data Store") {
            Picker("Where to keep your data", selection: Binding(
                get: { choice },
                set: { choice = $0 }
            )) {
                ForEach(DataStoreChoice.allCases) { c in
                    Text(c.title).tag(c)
                }
            }
            .pickerStyle(.inline)

            Text(
              choice == .iCloud
              ? "Using iCloud. Changes sync across your devices signed in with the same Apple ID."
              : "Using Local storage. Changes stay on this device only."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            // Migration entry
            Button {
                showMigration = true
            } label: {
                Label("Migrate Data…", systemImage: "arrow.left.arrow.right.circle")
            }
            .sheet(isPresented: $showMigration) {
                MigrationSheet()
            }
        }
    }
}
