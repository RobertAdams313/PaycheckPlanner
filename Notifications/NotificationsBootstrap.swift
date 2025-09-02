//
//  NotificationsBootstrap.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//

import SwiftUI
import SwiftData

struct NotificationsBootstrap: ViewModifier {
    @Environment(\.scenePhase) private var phase
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .task {
                await rescheduleNotifications(using: context)
            }
            .onChange(of: phase) { _, newValue in
                if newValue == .active {
                    Task { await rescheduleNotifications(using: context) }
                }
            }
    }
}

extension View {
    func withNotificationsBootstrap() -> some View {
        modifier(NotificationsBootstrap())
    }
}
