//
//  InsightsHostView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData
import Charts

// MARK: - Chart mode

enum InsightsChartMode: String, CaseIterable, Identifiable {
    case bar = "Bar"
    case pie = "Pie"
    var id: String { rawValue }
}

// MARK: - Host

struct InsightsHostView: View {
    @Query(sort: \Bill.dueDate) private var allBills: [Bill]

    /// Optional: when provided, the toggle can limit to just this interval.
    let currentPeriod: DateInterval?

    @State private var chartMode: InsightsChartMode = .bar
    @State private var showOnlyCurrentPeriod: Bool = true

    // Default-argument init so callers can do `InsightsHostView()`
    init(currentPeriod: DateInterval? = nil) {
        self.currentPeriod = currentPeriod
    }

    private var billsToShow: [Bill] {
        guard showOnlyCurrentPeriod, let p = currentPeriod else { return allBills }
        return Bill.bills(in: p, from: allBills)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Controls
            HStack(spacing: 12) {
                Picker("Chart", selection: $chartMode) {
                    ForEach(InsightsChartMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if currentPeriod != nil {
                    Toggle("This Period", isOn: $showOnlyCurrentPeriod)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .help("Show only bills that fall inside the current pay period")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Chart content
            switch chartMode {
            case .bar:
                InsightsChartSlice(bills: billsToShow)
            case .pie:
                InsightsPieSlice(bills: billsToShow)
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}
