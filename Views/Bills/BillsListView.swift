//
//  BillsListView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct BillsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bill.dueDate) private var bills: [Bill]

    var body: some View {
        List {
            ForEach(bills) { bill in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name).font(.headline)
                        Text("Due: \(bill.dueDate, style: .date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(bill.amount, format: .currency(code: "USD"))
                }
                .contentShape(Rectangle())
            }
            .onDelete { indexSet in
                for i in indexSet { context.delete(bills[i]) }
            }
        }
        .listStyle(.insetGrouped)
    }
}
