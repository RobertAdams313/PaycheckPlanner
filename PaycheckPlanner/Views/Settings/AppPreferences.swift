//
//  PreferencesKey.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  AppPreferences.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/2/25.
//

import Foundation

enum PreferencesKey {
    static let defaultTab = "defaultTab"
    static let billsGrouping = "billsGrouping"
    static let hapticsEnabled = "hapticsEnabled"
    static let reducedMotion = "reducedMotion"
    static let carryoverEnabled = "carryoverEnabled"
    static let enforceBillEndDates = "enforceBillEndDates"
    static let creditCardTrackingEnabled = "creditCardTrackingEnabled"
    static let insightsChartStyle = "insightsChartStyle"
    static let roundingPref = "roundingPref"
    static let paydayNotifications = "paydayNotifications"
    static let billDueNotifications = "billDueNotifications"
    static let billReminderDays = "billReminderDays"
}

enum AppPreferences {
    private static let ud = UserDefaults.standard

    static var defaultTabRaw: String {
        ud.string(forKey: PreferencesKey.defaultTab) ?? "plan"
    }

    static var billsGrouping: String {
        ud.string(forKey: PreferencesKey.billsGrouping) ?? "dueDate"
    }

    static var hapticsEnabled: Bool {
        ud.object(forKey: PreferencesKey.hapticsEnabled) as? Bool ?? true
    }

    static var reducedMotion: Bool {
        ud.object(forKey: PreferencesKey.reducedMotion) as? Bool ?? false
    }

    static var carryoverEnabled: Bool {
        ud.object(forKey: PreferencesKey.carryoverEnabled) as? Bool ?? true
    }

    static var enforceBillEndDates: Bool {
        ud.object(forKey: PreferencesKey.enforceBillEndDates) as? Bool ?? true
    }

    static var creditCardTrackingEnabled: Bool {
        ud.object(forKey: PreferencesKey.creditCardTrackingEnabled) as? Bool ?? false
    }

    static var insightsChartStyle: String {
        ud.string(forKey: PreferencesKey.insightsChartStyle) ?? "donut"
    }

    static var roundingPref: String {
        ud.string(forKey: PreferencesKey.roundingPref) ?? "exact"
    }

    static var paydayNotifications: Bool {
        ud.object(forKey: PreferencesKey.paydayNotifications) as? Bool ?? false
    }

    static var billDueNotifications: Bool {
        ud.object(forKey: PreferencesKey.billDueNotifications) as? Bool ?? false
    }

    static var billReminderDays: Int {
        ud.object(forKey: PreferencesKey.billReminderDays) as? Int ?? 3
    }
}
