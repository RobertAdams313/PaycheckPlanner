//
//  PaycheckPlannerApp.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData
import UserNotifications

@main
struct PaycheckPlannerApp: App {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled: Bool = true

    // Build the model container once at launch using the current toggle value.
    // Changing this later requires relaunch to re-create the container.
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([IncomeSource.self, Bill.self])

        // Read persisted toggle without SwiftUI wrappers during init:
        let enabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")

        let configuration: ModelConfiguration
        if enabled {
            // Managed CloudKit sync
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic   // uses container from entitlements
            )
        } else {
            // Local-only
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environment(\.icloudSyncEnabled, iCloudSyncEnabled) // convenience env key if you want
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - AppDelegate: registers for remote notifications when sync is enabled
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
            // Register for remote notifications (required for CloudKit background sync)
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // No-op for CloudKit-managed sync.
        // If you also use push provider/APNs, forward token here.
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Remote notification registration failed: \(error)")
    }
}

// MARK: - Optional Environment key for convenience
private struct iCloudSyncEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}
extension EnvironmentValues {
    var icloudSyncEnabled: Bool {
        get { self[iCloudSyncEnabledKey.self] }
        set { self[iCloudSyncEnabledKey.self] = newValue }
    }
}
