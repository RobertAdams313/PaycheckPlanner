import Foundation
import SwiftData

enum PayFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, biweekly, semimonthly, monthly
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .semimonthly: return "Semi-monthly"
        case .monthly: return "Monthly"
        }
    }
}

enum BillRecurrence: String, Codable, CaseIterable, Identifiable {
    case monthly, weekly, biweekly, once
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 Weeks"
        case .once: return "One-Time"
        }
    }
}

@Model
final class IncomeSource {
    var name: String
    var defaultAmount: Decimal
    var isActive: Bool
    var notes: String?
    init(name: String, defaultAmount: Decimal, isActive: Bool = true, notes: String? = nil) {
        self.name = name
        self.defaultAmount = defaultAmount
        self.isActive = isActive
        self.notes = notes
    }
}

@Model
final class IncomeOverride {
    var date: Date
    var amount: Decimal
    var sourceName: String
    init(date: Date, amount: Decimal, sourceName: String) {
        self.date = date
        self.amount = amount
        self.sourceName = sourceName
    }
}

@Model
final class PaySchedule {
    var frequency: PayFrequency
    var anchorDate: Date
    var paycheckAmount: Decimal
    var semimonthlyFirstDay: Int
    var semimonthlySecondDay: Int
    var incomeSources: [IncomeSource]

    init(
        frequency: PayFrequency = .biweekly,
        anchorDate: Date = .now,
        paycheckAmount: Decimal = 0,
        semimonthlyFirstDay: Int = 1,
        semimonthlySecondDay: Int = 15,
        incomeSources: [IncomeSource] = []
    ) {
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.paycheckAmount = paycheckAmount
        self.semimonthlyFirstDay = semimonthlyFirstDay
        self.semimonthlySecondDay = semimonthlySecondDay
        self.incomeSources = incomeSources
    }
}

@Model
final class Bill {
    var name: String
    var amount: Decimal
    var recurrence: BillRecurrence
    var anchorDueDate: Date
    var recurrenceEnd: Date?
    var notes: String?
    init(name: String, amount: Decimal, recurrence: BillRecurrence, anchorDueDate: Date, recurrenceEnd: Date? = nil, notes: String? = nil) {
        self.name = name
        self.amount = amount
        self.recurrence = recurrence
        self.anchorDueDate = anchorDueDate
        self.recurrenceEnd = recurrenceEnd
        self.notes = notes
    }
}

@Model
final class PaymentStatus {
    var billName: String
    var dueDate: Date
    var paid: Bool

    init(billName: String, dueDate: Date, paid: Bool = false) {
        self.billName = billName
        self.dueDate = dueDate
        self.paid = paid
    }
}

struct PayPeriod: Identifiable, Hashable {
    var id: UUID = .init()
    let start: Date
    let end: Date
    let payday: Date
}

struct AllocatedBill: Identifiable {
    var id: UUID = .init()
    let bill: Bill
    let dueDate: Date
}

struct PaycheckBreakdown: Identifiable {
    var id: UUID = .init()
    let period: PayPeriod
    let income: Decimal
    let allocated: [AllocatedBill]
    var totalBills: Decimal { allocated.reduce(0) { $0 + $1.bill.amount } }
    var leftover: Decimal { income - totalBills }
}
