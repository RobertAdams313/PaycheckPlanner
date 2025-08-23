import Foundation

// Bridge old names → new engine types from SafeAllocationEngine/CombinedPayEventsEngine
typealias PaycheckBreakdown = CombinedBreakdown
typealias AllocatedBill = AllocatedBillLine

// Minimal adapters so existing UI properties still work
extension CombinedBreakdown {
    var allocatedBills: [AllocatedBillLine] { items }
    var totalBills: Decimal { billsTotal }
    var income: Decimal { incomeTotal }
}

extension AllocatedBillLine {
    var name: String { bill.name }
    var amount: Decimal { amountEach }      // amount per occurrence
    var anchorDueDate: Date { bill.anchorDueDate }
    var recurrence: BillRecurrence { bill.recurrence }
}

