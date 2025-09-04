//  BillsListView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//

import SwiftUI
import SwiftData

struct BillsListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    @Query private var payments: [BillPayment]

    private let cal = Calendar.current

    private var buckets: [DueBucket] {
        let todayStart = cal.startOfDay(for: Date())
        let overdueEnd = cal.date(byAdding: .day, value: -1, to: todayStart)
        let next7End = cal.date(byAdding: .day, value: 7, to: todayStart)

        return [
            DueBucket(title: "Overdue", span: DateSpan(start: .distantPast, end: overdueEnd)),
            DueBucket(title: "Next 7 Days", span: DateSpan(start: todayStart, end: next7End)),
            DueBucket(title: "Later", span: DateSpan(start: cal.date(byAdding: .day, value: 8, to: todayStart) ?? todayStart, end: nil))
        ]
    }

    var body: some View {
        NavigationStack {
            Group {
                if bills.isEmpty {
                    ContentUnavailableView(
                        "No bills yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add a bill to see them organized by due date.")
                    )
                } else {
                    List {
                        ForEach(buckets) { bucket in
                            let bucketed = billsIn(bucket: bucket)
                            if !bucketed.isEmpty {
                                Section(bucket.title) {
                                    ForEach(bucketed) { bill in
                                        BillRow(bill: bill, isPaid: isPaid(bill))
                                            .billPaidSwipe(bill: bill, periodKey: periodKey(for: bill))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bills")
        }
    }

    private func periodKey(for bill: Bill) -> Date {
        cal.startOfDay(for: bill.anchorDueDate)
    }

    private func isPaid(_ bill: Bill) -> Bool {
        let pk = periodKey(for: bill)
        let id = bill.persistentModelID
        return payments.contains { $0.bill?.persistentModelID == id && $0.periodKey == pk }
    }

    private func billsIn(bucket: DueBucket) -> [Bill] {
        bills.filter { b in
            bucket.span.contains(b.anchorDueDate)
        }
    }
}

// MARK: - Bill Row

private struct BillRow: View {
    let bill: Bill
    let isPaid: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name.isEmpty ? "Untitled bill" : bill.name)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(bill.category.isEmpty ? "Uncategorized" : bill.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(dateString(bill.anchorDueDate))
                        .font(.caption)
                        .foregroundStyle(.tertiary) // ✅ ShapeStyle
                }
            }

            Spacer(minLength: 12)

            Text(currency(bill.amount))
                .monospacedDigit()
                .font(.body.weight(.semibold))

            Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary) // ✅ ShapeStyle
                .padding(.leading, 8)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private func currency(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
}
