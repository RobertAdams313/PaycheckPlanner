//
//  InsightsChartSlice.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import Charts

struct InsightsChartSlice: View {
    /// Provide the bills you want to visualize (e.g., filtered to a pay period)
    let bills: [Bill]

    var body: some View {
        Chart {
            ForEach(bills, id: \.id) { bill in
                BarMark(
                    x: .value("Amount", bill.amount.asDouble),
                    y: .value("Bill", bill.name)
                )
                .annotation(position: .trailing) {
                    Text(bill.amount.asDouble, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
        .padding()
        .navigationTitle("Bill Amounts")
        .navigationBarTitleDisplayMode(.inline)
    }
}
