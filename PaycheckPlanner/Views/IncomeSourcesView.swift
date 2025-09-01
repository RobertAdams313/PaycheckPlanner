//
//  IncomeSourcesView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

//
//  IncomeSourcesView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//

import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \IncomeSource.name, order: .forward)
    private var sources: [IncomeSource]

    @State private var showNew = false
    @State private var editing: IncomeSource?

    var body: some View {
        List {
            if sources.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("No income sources yet").font(.headline)
                        Text("Tap the + button to add your first income.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(sources) { src in
                    Button { editing = src } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(src.name).font(.body)
                                if let sched = src.schedule {
                                    Text("\(freqDisplayName(sched.frequency)) • \(sched.anchorDate, style: .date)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(currencyString(src.defaultAmount))
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
        // Create
        .sheet(isPresented: $showNew) {
            NavigationStack {
                IncomeEditorView(existing: nil) { _ in }
                    .navigationTitle("New Income")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        // Edit
        .sheet(item: $editing) { src in
            NavigationStack {
                IncomeEditorView(existing: src) { _ in }
                    .navigationTitle("Edit Income")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Local helpers (scoped to avoid redeclaration elsewhere)

    private func currencyString(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }

    private func freqDisplayName(_ freq: PayFrequency) -> String {
        switch freq {
        case .once:        return "Once"
        case .weekly:      return "Weekly"
        case .biweekly:    return "Every 2 Weeks"
        case .semimonthly: return "Twice a Month"
        case .monthly:     return "Monthly"
        }
    }

    private func delete(at offsets: IndexSet) {
        for idx in offsets { context.delete(sources[idx]) }
        try? context.save()
    }
}
