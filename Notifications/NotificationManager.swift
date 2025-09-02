//
//  NotificationManager.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Purpose: Central place to (re)schedule local notifications based on Settings.
//           Uses your CombinedPayEventsEngine + SafeAllocationEngine.
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - Public entry point

@MainActor
func rescheduleNotifications(using context: ModelContext) async {
    let defaults = UserDefaults.standard
    let paydayOn = defaults.bool(forKey: "paydayNotifications")
    let billOn   = defaults.bool(forKey: "billDueNotifications")
    let leadDays = max(0, defaults.integer(forKey: "billReminderDays"))

    // Ask once if needed
    NotificationScheduler.requestAuthorizationIfNeeded()

    // Clear our previously scheduled requests
    NotificationScheduler.removeAllScheduled(matching: "payday_")
    NotificationScheduler.removeAllScheduled(matching: "billdue_")

    guard paydayOn || billOn else { return }

    // Fetch SwiftData explicitly (no generic constraints issues)
    let schedules: [IncomeSchedule] = (try? context.fetch(FetchDescriptor<IncomeSchedule>())) ?? []
    let bills: [Bill]               = (try? context.fetch(FetchDescriptor<Bill>())) ?? []

    // Build current + future periods and allocate bills
    // Show the current open period + 8 upcoming
    let periods = CombinedPayEventsEngine.combinedPeriods(
        schedules: schedules,
        count: 9
    )
    let breakdowns = SafeAllocationEngine.allocate(bills: bills, into: periods)

    if paydayOn {
        schedulePaydayNotifications(from: breakdowns)
    }

    if billOn {
        scheduleBillDueNotifications(from: bills, leadDays: leadDays)
    }
}

// MARK: - Payday notifications

private func schedulePaydayNotifications(from breakdowns: [CombinedBreakdown]) {
    let cal = Calendar.current
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

    for b in breakdowns {
        // Fire at 9:00 AM local on payday
        guard let fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: b.period.payday),
              fire >= Date() else { continue }

        // Build body text without relying on Decimal extensions (avoid collisions)
        let income = formatCurrency(b.incomeTotal)
        let bills  = formatCurrency(b.billsTotal)
        let remain = formatCurrency(b.incomeTotal + b.carryIn - b.billsTotal)

        let id = "payday_" + df.string(from: b.period.payday) // stable, prevents dupes
        NotificationScheduler.scheduleOneShot(
            id: id,
            title: "Payday",
            body: "Income: \(income) • Bills: \(bills) • Remaining: \(remain)",
            fireDate: fire
        )
    }
}

// MARK: - Bill-due notifications

private func scheduleBillDueNotifications(from bills: [Bill], leadDays: Int) {
    let cal = Calendar.current
    let now = Date()
    let horizon = cal.date(byAdding: .month, value: 3, to: now) ?? now.addingTimeInterval(60 * 60 * 24 * 90)
    let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"

    for bill in bills {
        let dueDates = upcomingDueDates(for: bill, from: now, through: horizon, calendar: cal)
        for due in dueDates {
            // Fire at 9:00 AM leadDays before the due date (or same day if 0)
            let fireBase = cal.date(byAdding: .day, value: -leadDays, to: due) ?? due
            guard let fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: fireBase),
                  fire >= now else { continue }

            let pretty = dateMediumString(due)
            let id = "billdue_" + safeSlug(bill.name) + "_" + df.string(from: due)

            NotificationScheduler.scheduleOneShot(
                id: id,
                title: "Bill due soon",
                body: "\(bill.name.isEmpty ? "Untitled Bill" : bill.name) is due \(pretty).",
                fireDate: fire
            )
        }
    }
}

// MARK: - Recurrence → due dates (pure helpers)

private func upcomingDueDates(for bill: Bill,
                              from: Date,
                              through: Date,
                              calendar cal: Calendar) -> [Date] {
    var out: [Date] = []
    // Start at the first occurrence >= max(anchor, from)
    guard var current = firstOccurrence(onOrAfter: max(from, bill.anchorDueDate),
                                       anchor: bill.anchorDueDate,
                                       recurrence: bill.recurrence,
                                       calendar: cal) else { return out }

    while current <= through {
        out.append(current)
        current = nextOccurrence(after: current, recurrence: bill.recurrence, calendar: cal)
    }
    return out
}

private func firstOccurrence(onOrAfter date: Date,
                             anchor: Date,
                             recurrence: BillRecurrence,
                             calendar cal: Calendar) -> Date? {
    let date = cal.startOfDay(for: date)
    let anchor = cal.startOfDay(for: anchor)

    if date <= anchor { return anchor }

    switch recurrence {
    case .once:
        return nil
    case .weekly:
        return alignForward(anchor: anchor, stepDays: 7, onOrAfter: date, cal: cal)
    case .biweekly:
        return alignForward(anchor: anchor, stepDays: 14, onOrAfter: date, cal: cal)
    case .monthly:
        let day = max(1, min(28, cal.component(.day, from: anchor)))
        return nextMonthly(onOrAfter: date, day: day, cal: cal)
    case .semimonthly:
        // Generic: 15 + 30; if you store custom d1/d2, swap here.
        return nextSemiMonthly(onOrAfter: date, firstDay: 15, secondDay: 30, cal: cal)
    }
}

private func nextOccurrence(after d: Date,
                            recurrence: BillRecurrence,
                            calendar cal: Calendar) -> Date {
    switch recurrence {
    case .once:
        return d.addingTimeInterval(10 * 365 * 24 * 3600)
    case .weekly:
        return cal.date(byAdding: .day, value: 7, to: d).map(cal.startOfDay(for:)) ?? d
    case .biweekly:
        return cal.date(byAdding: .day, value: 14, to: d).map(cal.startOfDay(for:)) ?? d
    case .monthly:
        let day = cal.component(.day, from: d)
        let next = cal.date(byAdding: .month, value: 1, to: d) ?? d
        let y = cal.component(.year, from: next)
        let m = cal.component(.month, from: next)
        let clamped = min(day, daysInMonth(year: y, month: m, cal: cal))
        return makeDate(year: y, month: m, day: clamped, cal: cal)
    case .semimonthly:
        let dd = cal.component(.day, from: d)
        if dd <= 15 {
            let y = cal.component(.year, from: d)
            let m = cal.component(.month, from: d)
            let target = min(30, daysInMonth(year: y, month: m, cal: cal))
            return makeDate(year: y, month: m, day: target, cal: cal)
        } else {
            let next = cal.date(byAdding: .month, value: 1, to: d) ?? d
            let y = cal.component(.year, from: next)
            let m = cal.component(.month, from: next)
            return makeDate(year: y, month: m, day: 15, cal: cal)
        }
    }
}

// MARK: - Date utilities

private func alignForward(anchor: Date, stepDays: Int, onOrAfter lower: Date, cal: Calendar) -> Date {
    var d = anchor
    while d < lower {
        d = cal.date(byAdding: .day, value: stepDays, to: d) ?? d.addingTimeInterval(Double(stepDays) * 86400)
    }
    return cal.startOfDay(for: d)
}

private func nextMonthly(onOrAfter date: Date, day: Int, cal: Calendar) -> Date? {
    let y = cal.component(.year, from: date)
    let m = cal.component(.month, from: date)
    let d = cal.component(.day, from: date)
    if d <= day, day <= daysInMonth(year: y, month: m, cal: cal) {
        return makeDate(year: y, month: m, day: day, cal: cal)
    }
    let next = cal.date(byAdding: .month, value: 1, to: date) ?? date
    let y2 = cal.component(.year, from: next)
    let m2 = cal.component(.month, from: next)
    let clamped = min(day, daysInMonth(year: y2, month: m2, cal: cal))
    return makeDate(year: y2, month: m2, day: clamped, cal: cal)
}

private func nextSemiMonthly(onOrAfter date: Date, firstDay: Int, secondDay: Int, cal: Calendar) -> Date? {
    let y = cal.component(.year, from: date)
    let m = cal.component(.month, from: date)
    let d = cal.component(.day, from: date)
    let first = min(firstDay, daysInMonth(year: y, month: m, cal: cal))
    let second = min(secondDay, daysInMonth(year: y, month: m, cal: cal))

    if d <= first  { return makeDate(year: y, month: m, day: first, cal: cal) }
    if d <= second { return makeDate(year: y, month: m, day: second, cal: cal) }

    let next = cal.date(byAdding: .month, value: 1, to: date) ?? date
    let y2 = cal.component(.year, from: next)
    let m2 = cal.component(.month, from: next)
    return makeDate(year: y2, month: m2, day: first, cal: cal)
}

private func daysInMonth(year: Int, month: Int, cal: Calendar) -> Int {
    var comps = DateComponents(); comps.year = year; comps.month = month
    let dt = cal.date(from: comps) ?? Date()
    return cal.range(of: .day, in: .month, for: dt)?.count ?? 30
}

private func makeDate(year: Int, month: Int, day: Int, cal: Calendar) -> Date {
    var comps = DateComponents(); comps.year = year; comps.month = month; comps.day = day
    return cal.startOfDay(for: cal.date(from: comps) ?? Date())
}

// MARK: - Formatting (keep local to avoid extension collisions)

private func safeSlug(_ s: String) -> String {
    s.replacingOccurrences(of: " ", with: "_")
     .replacingOccurrences(of: "/", with: "-")
     .replacingOccurrences(of: ":", with: "-")
}

private func dateMediumString(_ d: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: d)
}


