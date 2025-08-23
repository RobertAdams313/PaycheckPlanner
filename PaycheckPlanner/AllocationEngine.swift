import Foundation

enum AllocationEngine {
    static func nextPaydays(schedule: PaySchedule, startingAfter date: Date, count: Int) -> [Date] {
        let cal = DateUtils.calendar
        var paydays: [Date] = []
        switch schedule.frequency {
        case .weekly:
            var d = schedule.anchorDate
            while d <= date { d = cal.date(byAdding: .day, value: 7, to: d)! }
            for _ in 0..<count { paydays.append(d); d = cal.date(byAdding: .day, value: 7, to: d)! }
        case .biweekly:
            var d = schedule.anchorDate
            while d <= date { d = cal.date(byAdding: .day, value: 14, to: d)! }
            for _ in 0..<count { paydays.append(d); d = cal.date(byAdding: .day, value: 14, to: d)! }
        case .semimonthly:
            var cursor = date
            cursor = DateUtils.calendar.date(from: DateUtils.calendar.dateComponents([.year, .month], from: cursor))!
            func makeDay(_ day: Int, in base: Date) -> Date {
                let range = DateUtils.calendar.range(of: .day, in: .month, for: base)!
                let clamped = min(max(1, day), range.count)
                return DateUtils.calendar.date(bySetting: .day, value: clamped, of: base)!
            }
            while paydays.count < count {
                let first = makeDay(schedule.semimonthlyFirstDay, in: cursor)
                let second = makeDay(schedule.semimonthlySecondDay, in: cursor)
                for pd in [first, second].sorted() {
                    if pd > date { paydays.append(pd) }
                    if paydays.count == count { break }
                }
                cursor = DateUtils.calendar.date(byAdding: .month, value: 1, to: cursor)!
            }
        case .monthly:
            var d = schedule.anchorDate
            while d <= date { d = DateUtils.addingMonthsPreservingDay(d, 1) }
            for _ in 0..<count { paydays.append(d); d = DateUtils.addingMonthsPreservingDay(d, 1) }
        }
        return paydays
    }

    static func periods(schedule: PaySchedule, upcoming count: Int = 6, from now: Date = .now) -> [PayPeriod] {
        let paydays = nextPaydays(schedule: schedule, startingAfter: now, count: count)
        var result: [PayPeriod] = []
        let cal = DateUtils.calendar
        var previous: Date

        switch schedule.frequency {
        case .weekly: previous = cal.date(byAdding: .day, value: -7, to: paydays.first!)!
        case .biweekly: previous = cal.date(byAdding: .day, value: -14, to: paydays.first!)!
        case .semimonthly:
            let first = paydays.first!
            var comps = cal.dateComponents([.year, .month], from: first)
            let firstDay = schedule.semimonthlyFirstDay
            let secondDay = schedule.semimonthlySecondDay
            let thisMonthFirst = cal.date(bySetting: .day, value: min(firstDay, 28), of: cal.date(from: comps)!)!
            let isFirst = cal.isDate(first, inSameDayAs: thisMonthFirst)
            if isFirst {
                comps.month = (comps.month ?? 1) - 1
                let lastMonthStart = cal.date(from: comps)!
                let prev = cal.date(bySetting: .day, value: min(secondDay, (cal.range(of: .day, in: .month, for: lastMonthStart)!.count)), of: lastMonthStart)!
                previous = prev
            } else {
                let prev = cal.date(bySetting: .day, value: min(firstDay, (cal.range(of: .day, in: .month, for: first)!.count)), of: first)!
                previous = prev
            }
        case .monthly: previous = DateUtils.addingMonthsPreservingDay(paydays.first!, -1)
        }

        for pd in paydays {
            let period = PayPeriod(start: previous, end: DateUtils.endOfDay(pd), payday: pd)
            result.append(period)
            previous = pd
        }
        return result
    }

    static func previousPaydays(schedule: PaySchedule, before date: Date, count: Int) -> [Date] {
        let cal = DateUtils.calendar
        let after = nextPaydays(schedule: schedule, startingAfter: date, count: 1).first ?? date
        var d = after
        var result: [Date] = []
        for _ in 0..<count {
            switch schedule.frequency {
            case .weekly: d = cal.date(byAdding: .day, value: -7, to: d)!
            case .biweekly: d = cal.date(byAdding: .day, value: -14, to: d)!
            case .monthly: d = DateUtils.addingMonthsPreservingDay(d, -1)
            case .semimonthly:
                let comps = cal.dateComponents([.year, .month], from: d)
                let startOfMonth = cal.date(from: comps)!
                let first = cal.date(bySetting: .day, value: 1, of: startOfMonth)!
                let second = cal.date(bySetting: .day, value: 15, of: startOfMonth)!
                d = cal.isDate(d, inSameDayAs: second) ? first : cal.date(byAdding: .month, value: -1, to: second)!
            }
            result.append(d)
        }
        return result
    }

    static func periodsPast(schedule: PaySchedule, count: Int = 6, from now: Date = .now) -> [PayPeriod] {
        let paydays = previousPaydays(schedule: schedule, before: now, count: count).reversed()
        let cal = DateUtils.calendar
        return paydays.map { pd in
            let start: Date
            switch schedule.frequency {
            case .weekly: start = cal.date(byAdding: .day, value: -7, to: pd)!
            case .biweekly: start = cal.date(byAdding: .day, value: -14, to: pd)!
            case .monthly: start = DateUtils.addingMonthsPreservingDay(pd, -1)
            case .semimonthly:
                let prev = previousPaydays(schedule: schedule, before: pd, count: 1).first ?? cal.date(byAdding: .day, value: -14, to: pd)!
                start = prev
            }
            return PayPeriod(start: start, end: DateUtils.endOfDay(pd), payday: pd)
        }
    }

    static func occurrences(for bill: Bill, in interval: DateInterval, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        let endCap = bill.recurrenceEnd ?? interval.end
        switch bill.recurrence {
        case .once:
            let d = DateUtils.endOfDay(bill.anchorDueDate)
            if d > interval.start && d <= interval.end { result.append(d) }
        case .weekly:
            var d = firstOccurrence(onOrAfter: interval.start, seed: bill.anchorDueDate, stepDays: 7, calendar: calendar)
            while d <= min(interval.end, endCap) { if d > interval.start { result.append(d) }; d = calendar.date(byAdding: .day, value: 7, to: d)! }
        case .biweekly:
            var d = firstOccurrence(onOrAfter: interval.start, seed: bill.anchorDueDate, stepDays: 14, calendar: calendar)
            while d <= min(interval.end, endCap) { if d > interval.start { result.append(d) }; d = calendar.date(byAdding: .day, value: 14, to: d)! }
        case .monthly:
            let day = calendar.component(.day, from: bill.anchorDueDate)
            var d = firstMonthlyOccurrence(onOrAfter: interval.start, seed: bill.anchorDueDate, day: day, calendar: calendar)
            while d <= min(interval.end, endCap) { if d > interval.start { result.append(d) }; d = DateUtils.addingMonthsPreservingDay(d, 1) }
        }
        return result
    }

    private static func firstOccurrence(onOrAfter target: Date, seed: Date, stepDays: Int, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: target)
        var d = calendar.startOfDay(for: seed)
        while d < start { d = calendar.date(byAdding: .day, value: stepDays, to: d)! }
        return DateUtils.endOfDay(d)
    }

    private static func firstMonthlyOccurrence(onOrAfter target: Date, seed: Date, day: Int, calendar: Calendar) -> Date {
        var d = calendar.startOfDay(for: seed)
        while d < calendar.startOfDay(for: target) { d = DateUtils.addingMonthsPreservingDay(d, 1) }
        return DateUtils.endOfDay(d)
    }

    static func incomeTotal(for payday: Date, schedule: PaySchedule, sources: [IncomeSource]) -> Decimal {
        var total: Decimal = schedule.paycheckAmount
        for src in sources where src.isActive {
            total += src.defaultAmount
        }
        return total
    }

    static func breakdowns(schedule: PaySchedule, bills: [Bill], incomeSources: [IncomeSource], upcoming count: Int = 6, from now: Date = .now) -> [PaycheckBreakdown] {
        let periods = periods(schedule: schedule, upcoming: count, from: now)
        return periods.map { p in
            let alloc = allocate(bills: bills, to: p)
            let inc = incomeTotal(for: p.payday, schedule: schedule, sources: incomeSources)
            return PaycheckBreakdown(period: p, income: inc, allocated: alloc)
        }
    }

    static func breakdownsPast(schedule: PaySchedule, bills: [Bill], incomeSources: [IncomeSource], count: Int = 6, from now: Date = .now) -> [PaycheckBreakdown] {
        let periods = periodsPast(schedule: schedule, count: count, from: now)
        return periods.map { p in
            let alloc = allocate(bills: bills, to: p)
            let inc = incomeTotal(for: p.payday, schedule: schedule, sources: incomeSources)
            return PaycheckBreakdown(period: p, income: inc, allocated: alloc)
        }
    }

    static func allocate(bills: [Bill], to period: PayPeriod) -> [AllocatedBill] {
        let interval = DateInterval(start: period.start, end: period.end)
        let cal = DateUtils.calendar
        return bills.flatMap { bill -> [AllocatedBill] in
            let dueDates = occurrences(for: bill, in: interval, calendar: cal)
            return dueDates.map { AllocatedBill(bill: bill, dueDate: $0) }
        }.sorted { $0.dueDate < $1.dueDate }
    }
}
