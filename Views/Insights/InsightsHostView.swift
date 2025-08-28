//
//  InsightsHostView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct InsightsHostView: View {
    @Query(sort: \Bill.dueDate) private var bills: [Bill]
    @State private var monthAnchor: Date = Date()

    private var monthBills: [Bill] {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: monthAnchor))!
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)!
        return bills.filter { $0.dueDate >= start && $0.dueDate < end }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    InsightsChartView(bills: monthBills)

                    // List by Tag (emoji + name)
                    let grouped = Dictionary(grouping: monthBills, by: { $0.insightsTag })
                    ForEach(grouped.keys.sorted(by: { $0.name < $1.name }), id: \.self) { tag in
                        let total = grouped[tag]?.reduce(0) { $0 + $1.amount } ?? 0
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(tag.emoji) \(tag.name)")
                                    Spacer()
                                    Text(total, format: .currency(code: "USD"))
                                }
                                .font(.headline)

                                ForEach(grouped[tag]!, id: \.id) { bill in
                                    HStack {
                                        Text(bill.name)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(bill.amount, format: .currency(code: "USD"))
                                    }
                                    .font(.subheadline)
                                }
                            }
                            .padding()
                            .background(.background.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .textCase(nil)
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                    } label: { Image(systemName: "chevron.left") }

                    Button {
                        monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
                    } label: { Image(systemName: "chevron.right") }
                }
            }
        }
    }
}
