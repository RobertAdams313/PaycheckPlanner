//
//  BillsListView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  BillsListView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  © 2025 Rob Adams. All rights reserved.
//

//
//  BillsListView.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//

import SwiftUI
import SwiftData

// MARK: - Bills List

struct BillsListView: View {
    @Environment(\.modelContext) private var context

    // Your Bill model is already SwiftData-backed. We sort by the computed `anchorDueDate` you added.
    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var bills: [Bill]

    private let cal = Calendar.current

    // Build the “date buckets” using the new DateSpan type
    private var buckets: [DueBucket] {
        let todayStart = cal.startOfDay(for: Date())

        let overdueEnd = cal.date(byAdding: .day, value: -1, to: todayStart)
        let next7End = cal.date(byAdding: .day, value: 7, to: todayStart)

        return [
            // Overdue: anything strictly before today
            DueBucket(title: "Overdue",
                      span: DateSpan(start: .distantPast, end: overdueEnd)),

            // Next 7 Days: [today ... today+7]
            DueBucket(title: "Next 7 Days",
                      span: DateSpan(start: todayStart, end: next7End)),

            // Later: after the next 7 days (open-ended)
            DueBucket(title: "Later",
                      span: DateSpan(start: cal.date(byAdding: .day, value: 8, to: todayStart) ?? todayStart,
                                     end: nil))
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
                                        BillRow(bill: bill)
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

    // MARK: - Helpers

    private func billsIn(bucket: DueBucket) -> [Bill] {
        bills.filter { b in
            bucket.span.contains(b.anchorDueDate)
        }
    }
}

// MARK: - Bill Row

private struct BillRow: View {
    let bill: Bill

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
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(currency(bill.amount))
                .monospacedDigit()
                .font(.body.weight(.semibold))
        }
        .contentShape(Rectangle())
        // (Optional) Tap action to push a detail if you have one:
        // .onTapGesture { /* navigate to Bill detail */ }
    }

    // Currency and date formatters kept local for clarity

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
