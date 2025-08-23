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

//
//  IncomeSourcesView.swift
//  PaycheckPlanner
//

import SwiftUI
import SwiftData

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.name, order: .forward) private var incomes: [IncomeSource]

    // Persisted preference to show/hide past one-time income
    @AppStorage("showPastOneTimeIncome") private var showPastOneTimeIncome: Bool = false

    // MARK: - Buckets
    private var recurring: [IncomeSource] {
        incomes.filter { $0.schedule?.frequency != .once }
    }

    private var upcomingOneTime: [IncomeSource] {
        let today = Calendar.current.startOfDay(for: Date())
        return incomes.filter { src in
            guard src.schedule?.frequency == .once, let d = src.schedule?.anchorDate else { return false }
            // Keep today & future in Upcoming
            return Calendar.current.startOfDay(for: d) >= today
        }
    }

    private var pastOneTime: [IncomeSource] {
        let today = Calendar.current.startOfDay(for: Date())
        return incomes.filter { src in
            guard src.schedule?.frequency == .once, let d = src.schedule?.anchorDate else { return false }
            // Strictly before today
            return Calendar.current.startOfDay(for: d) < today
        }
    }

    // MARK: - Body
    var body: some View {
        List {
            if !upcomingOneTime.isEmpty {
                Section("One-time (upcoming)") {
                    ForEach(upcomingOneTime) { src in row(for: src) }
                }
            }

            if !recurring.isEmpty {
                Section("Recurring") {
                    ForEach(recurring) { src in row(for: src) }
                }
            }

            if showPastOneTimeIncome, !pastOneTime.isEmpty {
                Section("One-time (past)") {
                    ForEach(pastOneTime) { src in row(for: src, dimmed: true) }
                }
            }

            if incomes.isEmpty {
                emptyState
            }
        }
        .animation(.default, value: showPastOneTimeIncome)
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle(isOn: $showPastOneTimeIncome) {
                        Label("Show Past One-time Income", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Income options")
            }
        }
    }

    // MARK: - Row
    @ViewBuilder
    private func row(for src: IncomeSource, dimmed: Bool = false) -> some View {
        NavigationLink {
            IncomeEditorView(existing: src) { _ in }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(src.name.isEmpty ? "Untitled" : src.name)
                        .font(.headline)
                    Text(subtitle(for: src))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(src.defaultAmount.currencyString)
                    .monospacedDigit()
            }
            .opacity(dimmed ? 0.55 : 1.0)
            .contentShape(Rectangle())
        }
        .swipeActions {
            Button(role: .destructive) {
                context.delete(src)
                try? context.save()
            } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func subtitle(for src: IncomeSource) -> String {
        guard let sched = src.schedule else { return src.variable ? "Variable" : "" }
        switch sched.frequency {
        case .once:
            // Show the one-time pay date for clarity
            return "One time • \(sched.anchorDate.formatted(date: .abbreviated, time: .omitted))"
        case .weekly, .biweekly, .monthly:
            return "\(sched.frequency.uiName) • \(sched.anchorDate.formatted(date: .abbreviated, time: .omitted))"
        case .semimonthly:
            return "Semi-monthly • \(sched.semimonthlyFirstDay) & \(sched.semimonthlySecondDay)"
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "banknote")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.tint)
            Text("No income yet")
                .font(.title3).bold()
            Text("Add your income sources here. You can also add One-time income for bonuses or single payments.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
    }
}
