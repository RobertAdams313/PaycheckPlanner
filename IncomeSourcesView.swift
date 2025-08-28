//
//  IncomeSourcesView.swift
//  Paycheck Planner
//
//  Created by Rob on 8/27/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.startDate) private var incomeSources: [IncomeSource]
    @State private var showingAddSource = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(incomeSources) { source in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name).font(.headline)
                        HStack(spacing: 6) {
                            Text("Starts \(source.startDate, style: .date)")
                            Text("•")
                            Text(source.frequency.capitalized)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        context.delete(incomeSources[index])
                    }
                }
            }
            .navigationTitle("Income")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSource = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSource) {
                IncomeEditorView()
            }
        }
    }
}
