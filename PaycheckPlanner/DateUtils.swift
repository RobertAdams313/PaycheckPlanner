import Foundation

enum DateUtils {
    static var calendar: Calendar { var c = Calendar.current; c.timeZone = .current; return c }
    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    static func endOfDay(_ date: Date) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }
    static func addingMonthsPreservingDay(_ date: Date, _ months: Int) -> Date {
        let day = calendar.component(.day, from: date)
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.month = (comps.month ?? 1) + months
        let firstOfTarget = calendar.date(from: comps) ?? date
        let maxDay = (calendar.range(of: .day, in: .month, for: firstOfTarget)?.count) ?? 28
        let clampedDay = min(day, maxDay)
        return calendar.date(bySetting: .day, value: clampedDay, of: firstOfTarget) ?? date
    }
}
