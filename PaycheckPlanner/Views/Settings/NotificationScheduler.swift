//
//  NotificationScheduler.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  NotificationScheduler.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/2/25.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
    }

    /// Example: schedule a simple local notification for a specific date.
    /// You’ll call this when you compute actual bill/payday dates.
    static func scheduleOneShot(id: String, title: String, body: String, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    /// Wipe previously scheduled notifications you own (call when toggles are turned off or when rescheduling).
    static func removeAllScheduled(matching prefix: String? = nil) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids: [String]
            if let p = prefix {
                ids = requests.map(\.identifier).filter { $0.hasPrefix(p) }
            } else {
                ids = requests.map(\.identifier)
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
