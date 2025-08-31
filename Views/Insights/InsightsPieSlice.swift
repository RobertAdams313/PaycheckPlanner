//
//  InsightsPieSlice.swift
//  Paycheck Planner
//
//  Created by Rob on 8/28/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import Charts

struct InsightsPieSlice: View {
    let bills: [Bill]
    
    private var totalsByCategory: [(category: String, amount: Double)] {
        Dictionary(grouping: bills, by: { $0.category })
            .map { (key, items) in
                (category: key, amount: items.reduce(0.0) { $0 + $1.amount.asDouble })
            }
            .sorted { $0.amount > $1.amount }
    }
    
    var body: some View {
        Chart(totalsByCategory, id: \.category) { item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.5),
                outerRadius: .ratio(1.0)
            )
            .annotation(position: .overlay) {
                if item.amount > 0 {
                    Text(item.category)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                }
            }
        }
        .padding()
        .frame(minHeight: 260)
        .accessibilityLabel("Spending by category")
    }
}
