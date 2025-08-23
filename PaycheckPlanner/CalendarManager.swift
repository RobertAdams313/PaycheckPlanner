//
//  CalendarManager.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


// CalendarManager.swift
// Paycheck Planner

import Foundation
import EventKit

@MainActor
final class CalendarManager {
    static let shared = CalendarManager()

    private let store = EKEventStore()
    private let calendarTitle = "Paycheck Planner"

    private init() {}

    // MARK: - Permissions

    /// Ensures the app has calendar access. Requests it if needed.
    func ensureAccess() async throws {
        if #available(iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .event)
            switch status {
            case .notDetermined:
                // Returns Bool; we don't actually need the value.
                _ = try await store.requestFullAccessToEvents()
            case .fullAccess, .writeOnly:
                break
            default:
                throw NSError(
                    domain: "CalendarManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Calendar access denied. Enable in Settings > Privacy > Calendars."]
                )
            }
        } else {
            let status = EKEventStore.authorizationStatus(for: .event)
            switch status {
            case .notDetermined:
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.store.requestAccess(to: .event) { granted, error in
                        if let error = error {
                            cont.resume(throwing: error)
                            return
                        }
                        guard granted else {
                            cont.resume(throwing: NSError(
                                domain: "CalendarManager",
                                code: 2,
                                userInfo: [NSLocalizedDescriptionKey: "Calendar access denied. Enable in Settings > Privacy > Calendars."]
                            ))
                            return
                        }
                        cont.resume(returning: ())
                    }
                }
            case .authorized:
                break
            default:
                throw NSError(
                    domain: "CalendarManager",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Calendar access denied. Enable in Settings > Privacy > Calendars."]
                )
            }
        }
    }

    // MARK: - Calendar

    /// Returns (or creates) the dedicated "Paycheck Planner" calendar.
    private func ensureCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing
        }

        // Choose a reasonable source (prefer default, then iCloud, then local, then first available)
        let chosenSource: EKSource? =
            store.defaultCalendarForNewEvents?.source ??
            store.sources.first(where: { $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("icloud") }) ??
            store.sources.first(where: { $0.sourceType == .local }) ??
            store.sources.first

        guard let source = chosenSource else {
            throw NSError(domain: "CalendarManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No calendar source available."])
        }

        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = calendarTitle
        cal.source = source
        try store.saveCalendar(cal, commit: true)
        return cal
    }

    // MARK: - Public API

    /// Adds a "Payday" event on the given date with an optional alert days before.
    func addPaydayEvent(date: Date, alertDaysBefore: Int) async throws {
        try await ensureAccess()
        let cal = try ensureCalendar()

        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start

        let event = EKEvent(eventStore: store)
        event.calendar = cal
        event.title = "Payday"
        event.startDate = start
        event.endDate = end

        if alertDaysBefore > 0 {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alertDaysBefore * 24 * 60 * 60)))
        }

        try store.save(event, span: .thisEvent, commit: true)
    }

    /// Adds a bill event, optionally recurring, with an alert days before.
    func addBillEvent(name: String, amount: Decimal, dueDate: Date, recurrence: String, alertDaysBefore: Int) async throws {
        try await ensureAccess()
        let cal = try ensureCalendar()

        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate) ?? dueDate
        let end = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start

        let event = EKEvent(eventStore: store)
        event.calendar = cal
        event.title = "\(name) — \(amount.currencyString)"
        event.startDate = start
        event.endDate = end

        if let rule = recurrenceRule(from: recurrence) {
            event.recurrenceRules = [rule]
        }

        if alertDaysBefore > 0 {
            event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-alertDaysBefore * 24 * 60 * 60)))
        }

        try store.save(event, span: .futureEvents, commit: true)
    }

    // MARK: - Helpers

    private func recurrenceRule(from str: String) -> EKRecurrenceRule? {
        let s = str.lowercased()
        if s.contains("weekly") && !s.contains("bi") {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        } else if s.contains("biweekly") || (s.contains("every 2") && s.contains("week")) {
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        } else if s.contains("monthly") {
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        } else {
            return nil
        }
    }
}
