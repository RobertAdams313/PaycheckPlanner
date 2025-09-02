//
//  NotificationsCoordinator.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//

import Foundation
import UserNotifications

extension Notification.Name {
    /// Broadcast when you want to open a specific payday detail (userInfo["payday"] = "yyyy-MM-dd")
    static let openPaycheckDetail = Notification.Name("OpenPaycheckDetail")
}

final class NotificationsCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationsCoordinator()
    private override init() { super.init() }

    // Show banner even in foreground (optional)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Handle user taps
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // If you later add userInfo to NotificationScheduler.scheduleOneShot,
        // you can pull it here and post .openPaycheckDetail with the payday string.
        // For now, payday deep-link is handled by NotificationDeepLink using identifier parsing if desired.
    }
}
