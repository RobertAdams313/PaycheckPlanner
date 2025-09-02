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
//  Updated on 9/1/25
//

import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context

    @Query(
        FetchDescriptor<IncomeSource>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
    )
    private var sources: [IncomeSource]

    @State private var showNew: Bool = false
    @State private var editing: IncomeSource? = nil

    // Drive the edit sheet with a Bool (avoids ambiguous .sheet(item:) overloads)
    private var isEditingPresented: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    var body: some View {
        List {
            if sources.isEmpty {
                ContentUnavailableView(
                    "No income sources",
                    systemImage: "banknote",
                    description: Text("Tap **Add** to create an income source and schedule.")
                )
            } else {
                Section("Sources") {
                    ForEach(sources) { src in
                        Button { editing = src } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(src.name.isEmpty ? "Untitled income" : src.name)
                                        .font(.body)
                                    Text(scheduleSubtitle(for: src))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(currency(src.defaultAmount))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                            .contentShape(Rectangle()) // full-row tap
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit income \(src.name)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let sched = src.schedule { context.delete(sched) }
                                context.delete(src)
                                try? context.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNew = true
                } label: {
                    Label("Add Income", systemImage: "plus")
                }
                .accessibilityLabel("Add Income")
            }
        }
        // New income sheet — explicit content: avoids trailing-closure ambiguity
        .sheet(isPresented: $showNew, content: {
            IncomeEditorView(existing: nil)
        })
        // Edit income sheet — Bool binding + explicit content
        .sheet(isPresented: isEditingPresented, content: {
            IncomeEditorView(existing: editing)
        })
        // OPTIONAL: background debug probe (safe; remove entirely if not needed)
        .task {
            do {
                try await context.background { bg in
                    let count = try bg.fetch(FetchDescriptor<IncomeSource>()).count
                    print("🔎 IncomeSourcesView sees \(count) income sources")
                }
            } catch {
                print("🔧 IncomeSourcesView probe failed: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func scheduleSubtitle(for src: IncomeSource) -> String {
        guard let s = src.schedule else { return "No schedule" }
        switch s.frequency {
        case .weekly:
            return "Weekly • Start \(formatDate(s.anchorDate))"
        case .biweekly:
            return "Biweekly • Start \(formatDate(s.anchorDate))"
        case .semimonthly:
            return "Semimonthly • \(s.semimonthlyFirstDay) & \(s.semimonthlySecondDay)"
        case .monthly:
            return "Monthly • Start \(formatDate(s.anchorDate))"
        default:
            return "Custom schedule • Start \(formatDate(s.anchorDate))"
        }
    }

    private func currency(_ d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f.string(from: n) ?? "$0.00"
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }
}
