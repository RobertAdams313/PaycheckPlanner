//
//  InsightsChartSlice.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import Charts

struct InsightsChartSlice: Identifiable {
    var id: String { tag.name }
    let tag: TagDef
    let total: Double
}

struct InsightsChartView: View {
    let bills: [Bill]

    private var slices: [InsightsChartSlice] {
        let grouped = Dictionary(grouping: bills, by: { $0.insightsTag })
        return grouped.map { (tag, items) in
            InsightsChartSlice(tag: tag, total: items.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month by Category")
                .font(.headline)

            if slices.isEmpty {
                Text("No bills this month.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Total", slice.total),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", slice.tag.name))
                    .annotation(position: .overlay) {
                        Text(slice.tag.emoji)
                            .font(.caption)
                    }
                }
                .frame(height: 240)
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
