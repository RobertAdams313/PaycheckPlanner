//
//  IncomeProjectionEngine.swift
//  PaycheckPlanner
//

import Foundation

struct IncomeOccurrence: Identifiable, Hashable, Codable {
    let id: UUID
    let incomeID: UUID
    let name: String
    let date: Date
    let amount: Decimal
    let frequency: IncomeFrequency

    init(incomeID: UUID, name: String, date: Date, amount: Decimal, frequency: IncomeFrequency) {
        self.id = UUID()
        self.incomeID = incomeID
        self.name = name
        self.date = date
        self.amount = amount
        self.frequency = frequency
    }
}

func incomeOccurrences(for incomes: [Income], in period: DateInterval, calendar: Calendar = .current) -> [IncomeOccurrence] {
    incomes.flatMap { occurrences(of: $0, in: period, calendar: calendar) }
}

func totalIncomeAmount(for incomes: [Income], in period: DateInterval, calendar: Calendar = .current) -> Decimal {
    incomeOccurrences(for: incomes, in: period, calendar: calendar).reduce(0) { $0 + $1.amount }
}

func occurrences(of income: Income, in period: DateInterval, calendar: Calendar = .current) -> [IncomeOccurrence] {
    switch income.frequency {
    case .oneTime:
        let d = (income.oneTimeDate ?? income.startDate).startOfDay(in: calendar)
        guard period.contains(d) else { return [] }
        return [IncomeOccurrence(incomeID: income.id, name: income.name, date: d, amount: income.amount, frequency: .oneTime)]
    case .weekly:
        return expandWeekly(anchor: income.startDate, amount: income.amount, name: income.name, incomeID: income.id, every: 1, in: period, calendar: calendar, frequency: .weekly)
    case .biweekly:
        return expandWeekly(anchor: income.startDate, amount: income.amount, name: income.name, incomeID: income.id, every: 2, in: period, calendar: calendar, frequency: .biweekly)
    case .monthly:
        return expandMonthly(anchor: income.startDate, amount: income.amount, name: income.name, incomeID: income.id, in: period, calendar: calendar)
    case .yearly:
        return expandYearly(anchor: income.startDate, amount: income.amount, name: income.name, incomeID: income.id, in: period, calendar: calendar)
    }
}

private func expandWeekly(anchor: Date, amount: Decimal, name: String, incomeID: UUID, every weeks: Int, in period: DateInterval, calendar: Calendar, frequency: IncomeFrequency) -> [IncomeOccurrence] {
    precondition(weeks >= 1)
    let start = period.start.startOfDay(in: calendar)
    let end = period.end.startOfDay(in: calendar)

    let anchorDay = anchor.startOfDay(in: calendar)
    let weekday = calendar.component(.weekday, from: anchorDay)

    guard var candidate = calendar.nextDate(after: start.addingTimeInterval(-1),
                                            matching: DateComponents(weekday: weekday),
                                            matchingPolicy: .nextTime,
                                            direction: .forward)?.startOfDay(in: calendar) else { return [] }

    if weeks > 1 {
        let days = calendar.dateComponents([.day], from: anchorDay, to: candidate).day ?? 0
        let weeksBetween = Int(floor(Double(days) / 7.0))
        let remainder = ((weeksBetween % weeks) + weeks) % weeks
        if remainder != 0, let aligned = calendar.date(byAdding: .day, value: (weeks - remainder) * 7, to: candidate) {
            candidate = aligned.startOfDay(in: calendar)
        }
    } else if candidate < anchorDay {
        if let next = calendar.nextDate(after: anchorDay.addingTimeInterval(-1),
                                        matching: DateComponents(weekday: weekday),
                                        matchingPolicy: .nextTime,
                                        direction: .forward) {
            candidate = next.startOfDay(in: calendar)
        }
    }

    var out: [IncomeOccurrence] = []
    var iter = 0
    while candidate < end && iter < 520 {
        if candidate >= start && candidate >= anchorDay && period.contains(candidate) {
            out.append(.init(incomeID: incomeID, name: name, date: candidate, amount: amount, frequency: frequency))
        }
        iter += 1
        guard let next = calendar.date(byAdding: .day, value: weeks * 7, to: candidate) else { break }
        candidate = next.startOfDay(in: calendar)
    }
    return out
}

private func expandMonthly(anchor: Date, amount: Decimal, name: String, incomeID: UUID, in period: DateInterval, calendar: Calendar) -> [IncomeOccurrence] {
    let start = period.start.startOfDay(in: calendar)
    let end = period.end.startOfDay(in: calendar)
    let anchorDay = anchor.startOfDay(in: calendar)
    let dom = calendar.component(.day, from: anchorDay)

    var cursor = monthOccurrence(onOrAfter: max(start, anchorDay), day: dom, calendar: calendar) ?? anchorDay
    if cursor < anchorDay {
        cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? cursor
        cursor = adjustedDayOfMonth(cursor, desiredDay: dom, calendar: calendar)
    }

    var out: [IncomeOccurrence] = []
    var iter = 0
    while cursor < end && iter < 240 {
        if cursor >= start && period.contains(cursor) {
            out.append(.init(incomeID: incomeID, name: name, date: cursor, amount: amount, frequency: .monthly))
        }
        iter += 1
        guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
        cursor = adjustedDayOfMonth(next, desiredDay: dom, calendar: calendar)
    }
    return out
}

private func expandYearly(anchor: Date, amount: Decimal, name: String, incomeID: UUID, in period: DateInterval, calendar: Calendar) -> [IncomeOccurrence] {
    let start = period.start.startOfDay(in: calendar)
    let end = period.end.startOfDay(in: calendar)
    let anchorDay = anchor.startOfDay(in: calendar)
    var comps = calendar.dateComponents([.month, .day], from: anchorDay)
    var year = max(calendar.component(.year, from: start), calendar.component(.year, from: anchorDay))

    var out: [IncomeOccurrence] = []
    var iter = 0
    while iter < 50 {
        comps.year = year
        guard let candidate = calendar.date(from: comps)?.startOfDay(in: calendar) else { break }
        if candidate >= anchorDay && candidate >= start && candidate < end && period.contains(candidate) {
            out.append(.init(incomeID: incomeID, name: name, date: candidate, amount: amount, frequency: .yearly))
        } else if candidate >= end {
            break
        }
        iter += 1
        year += 1
    }
    return out
}

private func adjustedDayOfMonth(_ dateInMonth: Date, desiredDay: Int, calendar: Calendar) -> Date {
    let range: Range<Int> = calendar.range(of: .day, in: .month, for: dateInMonth) ?? (1..<29) // Range on both sides
    let clamped = min(max(desiredDay, range.lowerBound), range.upperBound)
    var comps = calendar.dateComponents([.year, .month], from: dateInMonth)
    comps.day = clamped
    return (calendar.date(from: comps) ?? dateInMonth).startOfDay(in: calendar)
}

private func monthOccurrence(onOrAfter start: Date, day: Int, calendar: Calendar) -> Date? {
    let candidate = adjustedDayOfMonth(start, desiredDay: day, calendar: calendar)
    if candidate >= start { return candidate }
    guard let next = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
    return adjustedDayOfMonth(next, desiredDay: day, calendar: calendar)
}

private extension Date {
    func startOfDay(in calendar: Calendar) -> Date { calendar.startOfDay(for: self) }
}
