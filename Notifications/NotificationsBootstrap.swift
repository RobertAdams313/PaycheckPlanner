//
//  NotificationsBootstrap.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Updated on 9/3/25 – Adds rescheduleNotifications(using:) that defers to NotificationManager
//

import SwiftUI
import SwiftData

// MARK: - View Modifier

struct NotificationsBootstrap: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            // Initial bootstrap on launch
            .task {
                await rescheduleNotifications(using: context)
            }
            // Refresh when returning to foreground
            .onChange(of: phase) { _, newValue in
                if newValue == .active {
                    Task { await rescheduleNotifications(using: context) }
                }
            }
    }
}

// MARK: - Public View API

extension View {
    func withNotificationsBootstrap() -> some View {
        modifier(NotificationsBootstrap())
    }
}

// MARK: - Implementation

/// Reads your current settings and rebuilds notifications via NotificationManager.
/// Safe to call repeatedly; it internally requests authorization if needed.
@MainActor
private func rescheduleNotifications(using context: ModelContext) async {
    // Read the same storage keys used elsewhere to keep behavior unified.
    // If the key hasn't been set yet, fall back to 3 periods.
    let rawCount = (UserDefaults.standard.object(forKey: "planPeriodCount") as? Int) ?? 3
    let count = max(rawCount, 1)

    await NotificationManager.rebuildAllNotifications(
        context: context,
        count: count,
        calendar: .current
    )
}
