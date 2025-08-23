import SwiftUI

struct PaycheckDetailView: View {
    let breakdown: PaycheckBreakdown
    let allSources: [IncomeSource]
    let schedule: PaySchedule

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Payday", value: breakdown.period.payday.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Income", value: formatCurrency(breakdown.income)).monospacedDigit()
                LabeledContent("Total Bills", value: formatCurrency(breakdown.totalBills)).monospacedDigit()
                LabeledContent("Leftover", value: formatCurrency(breakdown.leftover)).monospacedDigit()
            }
            Section("Calendar") {
                Button("Add this paycheck to Calendar") {
                    Task {
                        try? await CalendarManager.shared.addPaydayEvent(date: breakdown.period.payday)
                        for a in breakdown.allocated {
                            try? await CalendarManager.shared.addBillEvent(name: a.bill.name, amount: a.bill.amount, dueDate: a.dueDate, recurrence: a.bill.recurrence, recurrenceEnd: a.bill.recurrenceEnd)
                        }
                    }
                }
            }
            Section("Bills in this paycheck") {
                if breakdown.allocated.isEmpty {
                    ContentUnavailableView("No bills", systemImage: "checkmark.circle", description: Text("No bills are due between the last and this payday."))
                } else {
                    ForEach(breakdown.allocated) { a in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(a.bill.name).font(.headline)
                                if let notes = a.bill.notes, !notes.isEmpty { Text(notes).foregroundStyle(.secondary).font(.subheadline) }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(a.dueDate, style: .date)
                                Text(formatCurrency(a.bill.amount)).bold().monospacedDigit()
                            }
                        }
                    }
                }
            }
        }.navigationTitle("Paycheck")
    }
}
