//
//  NotificationManager.swift
//  PaycheckPlanner
//
//  Built to your current engine stack:
//  - Uses CombinedPayEventsEngine.upcomingBreakdowns(context:count:from:calendar:)
//  - Builds notification IDs with SharedAppGroup.billID(name, dueDate)
//  - Respects simple UserDefaults toggles for bill/income notifications
//

import Foundation
import UserNotifications
import SwiftData

enum NotificationManager {

    // MARK: - Public API

    /// Ask for permission if not determined.
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    /// Rebuild all upcoming notifications (bills + payday).
    @MainActor
    static func rebuildAllNotifications(
        context: ModelContext,
        count: Int = 3,
        calendar: Calendar = .current
    ) async {
        await requestAuthorizationIfNeeded()
        await cancelAllScheduled()

        let billsOn = (UserDefaults.standard.object(forKey: "notifyBillsEnabled") as? Bool) ?? true
        let incomeOn = (UserDefaults.standard.object(forKey: "notifyIncomeEnabled") as? Bool) ?? true

        if billsOn {
            await scheduleUpcomingBills(context: context, count: count, calendar: calendar)
        }
        if incomeOn {
            await scheduleNextPaydays(context: context, count: count, calendar: calendar)
        }
    }

    /// Cancel everything we scheduled.
    static func cancelAllScheduled() async {
        let center = UNUserNotificationCenter.current()
        await center.removeAllPendingNotificationRequests()
    }

    // MARK: - Bills

    /// Schedule bill notifications for the next N breakdown periods.
    @MainActor
    static func scheduleUpcomingBills(
        context: ModelContext,
        count: Int,
        calendar: Calendar = .current
    ) async {
        _ = UNUserNotificationCenter.current()

        // Build breakdowns with your convenience (periods -> allocation already applied).
        let breakdowns = CombinedPayEventsEngine.upcomingBreakdowns(
            context: context,
            count: count,
            from: Date(),
            calendar: calendar
        )

        for breakdown in breakdowns {
            // For each allocated bill line, schedule once at its due day (start-of-day).
            for line in breakdown.items {
                let bill = line.bill

                // Derive due dates in this [start,end) window according to recurrence.
                let dues = dueDates(
                    for: bill,
                    in: breakdown.period.start,
                    breakdown.period.end,
                    cal: calendar
                )
                for due in dues {
                    let id = SharedAppGroup.billID(bill.name, due)
                    let title = bill.name
                    let amountStr = currencyString(bill.amount)
                    let body = "Due today • \(amountStr)"

                    // Fire at 9am local time on the due date (tweak if desired).
                    if let triggerDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: due) {
                        await scheduleLocalNotification(
                            id: "bill|\(id)",
                            title: title,
                            body: body,
                            triggerAt: triggerDate
                        )
                    }
                }
            }
        }
    }

    // MARK: - Paydays

    /// Schedule payday notifications for the next N breakdown periods.
    @MainActor
    static func scheduleNextPaydays(
        context: ModelContext,
        count: Int,
        calendar: Calendar = .current
    ) async {
        _ = UNUserNotificationCenter.current()

        let breakdowns = CombinedPayEventsEngine.upcomingBreakdowns(
            context: context,
            count: count,
            from: Date(),
            calendar: calendar
        )

        for b in breakdowns {
            let title = "Payday"
            let body = "Income: \(currencyString(b.incomeTotal)) • Bills: \(currencyString(b.billsTotal)) • Leftover: \(currencyString(b.leftover))"
            // Notify morning of payday.
            if let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: b.period.payday) {
                let id = paydayID(for: b.period.payday)
                await scheduleLocalNotification(
                    id: "payday|\(id)",
                    title: title,
                    body: body,
                    triggerAt: morning
                )
            }
        }
    }

    // MARK: - Low-level scheduling

    private static func scheduleLocalNotification(
        id: String,
        title: String,
        body: String,
        triggerAt: Date
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(req)
        } catch {
            #if DEBUG
            print("Failed to schedule \(id): \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Bill-specific due dates inside [start, end).
    /// Matches SafeAllocationEngine rules (anchor clamp / endDate stop).
    private static func dueDates(
        for bill: Bill,
        in start: Date,
        _ end: Date,
        cal: Calendar
    ) -> [Date] {
        // Mirror the allocation rules to derive concrete due days.
        let anchor = cal.startOfDay(for: bill.anchorDueDate)
        let lower = max(cal.startOfDay(for: start), anchor)

        var upper = end
        if let until = bill.endDate {
            let dayAfter = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: until)) ?? until
            upper = min(upper, dayAfter)
        }
        if upper <= lower { return [] }

        switch bill.recurrence {
        case .once:
            let d = cal.startOfDay(for: bill.anchorDueDate)
            return (d >= lower && d < upper) ? [d] : []

        case .weekly:
            return strideDays(anchor: anchor, every: 7, atOrAfter: lower, before: upper, cal: cal)

        case .biweekly:
            return strideDays(anchor: anchor, every: 14, atOrAfter: lower, before: upper, cal: cal)

        case .monthly:
            let day = cal.component(.day, from: bill.anchorDueDate)
            return strideMonthly(days: [day], atOrAfter: lower, before: upper, cal: cal)

        case .semimonthly:
            // Default common pattern without per-bill days: 1 & 15
            return strideMonthly(days: [1, 15], atOrAfter: lower, before: upper, cal: cal)
        }
    }

    private static func strideDays(
        anchor: Date,
        every days: Int,
        atOrAfter lower: Date,
        before upper: Date,
        cal: Calendar
    ) -> [Date] {
        var out: [Date] = []
        let lowerDay = cal.startOfDay(for: lower)
        var d = cal.startOfDay(for: anchor)
        while d < lowerDay { d = cal.date(byAdding: .day, value: days, to: d) ?? d }
        while d < upper {
            out.append(cal.startOfDay(for: d))
            d = cal.date(byAdding: .day, value: days, to: d) ?? d
        }
        return out
    }

    private static func strideMonthly(
        days: [Int],
        atOrAfter lower: Date,
        before upper: Date,
        cal: Calendar
    ) -> [Date] {
        var out: [Date] = []
        var comps = cal.dateComponents([.year, .month], from: lower)

        while true {
            guard let y = comps.year, let m = comps.month, let monthStart = cal.date(from: comps) else { break }
            // Use half-open Range and compute the last valid day correctly
            let range: Range<Int> = cal.range(of: .day, in: .month, for: monthStart) ?? (1..<29)
            let firstDay = range.lowerBound
            let lastDay  = range.upperBound - 1

            for d in days.sorted() {
                let dd = max(firstDay, min(lastDay, d))
                if let candidate = cal.date(from: DateComponents(year: y, month: m, day: dd)) {
                    let c = cal.startOfDay(for: candidate)
                    if c >= cal.startOfDay(for: lower), c < upper {
                        out.append(c)
                    }
                }
            }

            guard let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart), nextMonth < upper else {
                break
            }
            comps = cal.dateComponents([.year, .month], from: nextMonth)
        }
        return out
    }

    private static func paydayID(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "y\(c.year ?? 0)m\(c.month ?? 0)d\(c.day ?? 0)"
    }

    private static func currencyString(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}
