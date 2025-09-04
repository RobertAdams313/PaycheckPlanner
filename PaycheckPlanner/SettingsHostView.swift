//
//  SettingsHostView.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/24/25.
//  Updated on 9/3/25 – Fixed imports, refactored presenters, integrated helpers.
//

import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Settings Snapshot (AppStorage)

private struct SettingsSnapshot: Codable {
    var planCount: Int
    var appearance: String
    var defaultTabRaw: String
    var billsGrouping: String
    var hapticsEnabled: Bool
    var carryoverEnabled: Bool
    var notifyBillsEnabled: Bool
    var notifyIncomeEnabled: Bool
}

// MARK: - Notification bridge for CSV import

extension Notification.Name {
    static let ppsCSVImportURLSelected = Notification.Name("PPSCSVImportURLSelected")
}

// MARK: - Host

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

    // Settings (JSON) backup/restore UI
    @State private var showSettingsExporter = false
    @State private var showSettingsImporter = false
    @State private var settingsExportURL: URL? = nil
    @State private var showResetConfirm = false
    @State private var settingsRestoreAlert: (title: String, message: String)? = nil
    @State private var settingsBackupAlert: (title: String, message: String)? = nil

    // Data CSV
    @State private var showDataCSVExporter = false
    @State private var dataCSVExportURL: URL? = nil
    @State private var dataCSVAlert: (title: String, message: String)? = nil
    @State private var showDataCSVImporter = false

    // Data JSON snapshots
    @State private var showDataJSONExporter = false
    @State private var dataJSONExportURL: URL? = nil
    @State private var dataJSONAlert: (title: String, message: String)? = nil
    @State private var showDataJSONImporter = false
    @State private var pendingJSONToImport: URL? = nil
    @State private var showJSONImportModeConfirm = false // Merge vs Replace

    var body: some View {
        let content = baseList()
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")

        let withSettings = applySettingsPresenters(to: content)
        let withCSV      = applyCSVPresenters(to: withSettings)
        let withJSON     = applyJSONPresenters(to: withCSV)
        return withJSON
    }

    // MARK: - Base view (just the List)
    @ViewBuilder
    private func baseList() -> some View {
        List {
            // General
            Section {
                AppearanceSection(appearance: $appearance)
                DefaultTabSection(defaultTabRaw: $defaultTabRaw)
            } header: {
                Text("General")
            }

            // Planning
            Section {
                PlanningSection(planCount: $planCount,
                                billsGrouping: $billsGrouping,
                                carryoverEnabled: $carryoverEnabled,
                                hapticsEnabled: $hapticsEnabled)
            } header: {
                Text("Planning")
            }

            // Notifications
            Section {
                NotificationsSection(notifyBillsEnabled: $notifyBillsEnabled,
                                     notifyIncomeEnabled: $notifyIncomeEnabled)
            } header: {
                Text("Notifications")
            } footer: {
                Text("Adjust alert style in iOS Settings → Notifications → Paycheck Planner.")
            }

            // Settings (AppStorage) backup/restore
            Section {
                Button { performSettingsBackup() } label: {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("Back Up Settings")
                        Spacer()
                    }
                }

                Button { showSettingsImporter = true } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc")
                        Text("Restore Settings")
                        Spacer()
                    }
                }

                Button(role: .destructive) { showResetConfirm = true } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle")
                        Text("Reset Settings…")
                        Spacer()
                    }
                }
            } header: {
                Text("Settings")
            } footer: {
                Text("Back up or restore only app settings. Bills & Income aren’t changed here.")
            }

            // Data (CSV + JSON)
            Section {
                Button { performDataCSVBackup() } label: {
                    HStack {
                        Image(systemName: "externaldrive")
                        Text("Back Up Data (CSV)")
                        Spacer()
                    }
                }

                Button { showDataCSVImporter = true } label: {
                    HStack {
                        Image(systemName: "tray.and.arrow.down")
                        Text("Restore Data (CSV)")
                        Spacer()
                    }
                }

                Button { performDataJSONBackup() } label: {
                    HStack {
                        Image(systemName: "doc.zipper")
                        Text("Back Up Data (JSON Full Snapshot)")
                        Spacer()
                    }
                }

                Button { showDataJSONImporter = true } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.icloud")
                        Text("Restore Data (JSON Full Snapshot)")
                        Spacer()
                    }
                }

            } header: {
                Text("Data")
            } footer: {
                Text("CSV exports are table-friendly. JSON snapshots are full-fidelity; on restore you can Merge or Replace.")
            }
        }
    }

    // MARK: - Presenter groups (split out to lighten type-checking)

    private func applySettingsPresenters<V: View>(to view: V) -> some View {
        view
            .fileExporter(
                isPresented: $showSettingsExporter,
                document: settingsExportURL.map { TempFileDocument(fileURL: $0) },
                contentType: .json,
                defaultFilename: "PaycheckPlanner-Settings-\(dateStamp()).json"
            ) { result in
                switch result {
                case .success: settingsBackupAlert = ("Backup Complete", "Your settings JSON was exported successfully.")
                case .failure(let err): settingsBackupAlert = ("Backup Failed", err.localizedDescription)
                }
                cleanupTemp(&settingsExportURL)
            }
            .fileImporter(
                isPresented: $showSettingsImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleSettingsRestore(result)
            }
            .alert(settingsBackupAlert?.title ?? "",
                   isPresented: Binding(get: { settingsBackupAlert != nil },
                                       set: { if !$0 { settingsBackupAlert = nil } })) {
                Button("OK", role: .cancel) { settingsBackupAlert = nil }
            } message: {
                Text(settingsBackupAlert?.message ?? "")
            }
            .alert(settingsRestoreAlert?.title ?? "",
                   isPresented: Binding(get: { settingsRestoreAlert != nil },
                                       set: { if !$0 { settingsRestoreAlert = nil } })) {
                Button("OK", role: .cancel) { settingsRestoreAlert = nil }
            } message: {
                Text(settingsRestoreAlert?.message ?? "")
            }
            .confirmationDialog("Reset Settings",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Reset All Settings", role: .destructive) { resetAllSettings() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This restores defaults for appearance, default tab, planning, notifications, and haptics. Bills/Income data aren’t touched.")
            }
    }

    private func applyCSVPresenters<V: View>(to view: V) -> some View {
        view
            .fileExporter(
                isPresented: $showDataCSVExporter,
                document: dataCSVExportURL.map { TempFileDocument(fileURL: $0) },
                contentType: .commaSeparatedText,
                defaultFilename: "PaycheckPlanner-Data-\(dateStamp()).csv"
            ) { result in
                switch result {
                case .success: dataCSVAlert = ("Export Complete", "Your data CSV was exported successfully.")
                case .failure(let err): dataCSVAlert = ("Export Failed", err.localizedDescription)
                }
                cleanupTemp(&dataCSVExportURL)
            }
            .fileImporter(
                isPresented: $showDataCSVImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .failure(let err):
                    dataCSVAlert = ("Import Failed", err.localizedDescription)
                case .success(let urls):
                    if let url = urls.first {
                        NotificationCenter.default.post(name: .ppsCSVImportURLSelected, object: url)
                        dataCSVAlert = ("Import Ready", "Sent the selected CSV to the importer.")
                    } else {
                        dataCSVAlert = ("Import Failed", "No file selected.")
                    }
                }
            }
            .alert(dataCSVAlert?.title ?? "",
                   isPresented: Binding(get: { dataCSVAlert != nil },
                                       set: { if !$0 { dataCSVAlert = nil } })) {
                Button("OK", role: .cancel) { dataCSVAlert = nil }
            } message: {
                Text(dataCSVAlert?.message ?? "")
            }
    }

    private func applyJSONPresenters<V: View>(to view: V) -> some View {
        view
            .fileExporter(
                isPresented: $showDataJSONExporter,
                document: dataJSONExportURL.map { TempFileDocument(fileURL: $0) },
                contentType: .json,
                defaultFilename: "PaycheckPlanner-Data-\(dateStamp()).json"
            ) { result in
                switch result {
                case .success: dataJSONAlert = ("Export Complete", "Your data JSON snapshot was exported successfully.")
                case .failure(let err): dataJSONAlert = ("Export Failed", err.localizedDescription)
                }
                cleanupTemp(&dataJSONExportURL)
            }
            .fileImporter(
                isPresented: $showDataJSONImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .failure(let err):
                    dataJSONAlert = ("Import Failed", err.localizedDescription)
                case .success(let urls):
                    pendingJSONToImport = urls.first
                    showJSONImportModeConfirm = (pendingJSONToImport != nil)
                }
            }
            .confirmationDialog("Restore Data Snapshot",
                                isPresented: $showJSONImportModeConfirm,
                                titleVisibility: .visible) {
                Button("Merge (Keep existing, update matches)") {
                    importJSONSnapshot(mode: .merge)
                }
                Button("Replace All Data", role: .destructive) {
                    importJSONSnapshot(mode: .replace)
                }
                Button("Cancel", role: .cancel) {
                    pendingJSONToImport = nil
                }
            } message: {
                Text("Choose how to apply the snapshot. Merge updates or inserts without deleting; Replace wipes all bills & incomes first.")
            }
            .alert(dataJSONAlert?.title ?? "",
                   isPresented: Binding(get: { dataJSONAlert != nil },
                                       set: { if !$0 { dataJSONAlert = nil } })) {
                Button("OK", role: .cancel) { dataJSONAlert = nil }
            } message: {
                Text(dataJSONAlert?.message ?? "")
            }
    }

    // MARK: - Helpers (dateStamp, cleanup, encode/decode)

    private func cleanupTemp(_ url: inout URL?) {
        if let u = url { try? FileManager.default.removeItem(at: u) }
        url = nil
    }
}

// MARK: - TempFileDocument

private struct TempFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }
    init(configuration: ReadConfiguration) throws {
        self.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: fileURL)
        return .init(regularFileWithContents: data)
    }
}

// MARK: - Global helpers

func dateStamp() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyyMMdd-HHmmss"
    return f.string(from: Date())
}

func encodeSnapshot<T: Encodable>(_ value: T) throws -> Data {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted]
    enc.dateEncodingStrategy = .iso8601
    return try enc.encode(value)
}

func decodeSnapshot<T: Decodable>(_ data: Data, as: T.Type = T.self) throws -> T {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .iso8601
    return try dec.decode(T.self, from: data)
}
