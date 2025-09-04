//
//  IncomeSourcesView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/3/25 – Adds “Main income” UI (star badge, swipe action, context menu) without removing existing behaviors.
//                       Preserves Card UI parity; explicit NavigationLink(destination:) to avoid value-based routing stalls
//

import SwiftUI
import SwiftData

// MARK: - Helpers

private func dateMedium(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: date)
}

private func frequencyLabel(_ freq: PayFrequency) -> String {
    switch freq {
    case .once:         return "One-time"
    case .weekly:       return "Weekly"
    case .biweekly:     return "Bi-weekly"
    case .semimonthly:  return "Semi-monthly"
    case .monthly:      return "Monthly"
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

// MARK: - View

struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \IncomeSource.name, order: .forward)
    private var sources: [IncomeSource]

    @State private var draftNewSource: IncomeSource?
    @State private var showingAdd = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                headerBar

                if sources.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(sources) { src in
                            // Explicit destination avoids type-based routing & potential stalls
                            NavigationLink {
                                IncomeEditorView(existing: src)
                            } label: {
                                FrostCard { incomeRow(src) }
                            }
                            .buttonStyle(.plain)
                            .contextMenu { mainContextMenu(for: src) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                mainSwipeActions(for: src)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addSource()
                    showingAdd = true
                } label: {
                    Label("Add Income", systemImage: "plus")
                }
            }
        }
        // Present editor plainly; avoid `.sheet(item:)` re-identifying the SwiftData object during layout
        .sheet(isPresented: $showingAdd) {
            if let newSrc = draftNewSource {
                NavigationStack {
                    IncomeEditorView(existing: newSrc)
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Text("Your income")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(sources.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("Total income sources")
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Row

    @ViewBuilder
    private func incomeRow(_ src: IncomeSource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            // Leading badge for "main"
            if let sched = src.schedule, sched.isMain {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(src.name.isEmpty ? "Untitled Income" : src.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let sched = src.schedule, sched.isMain {
                        Text("Main")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.yellow.opacity(0.18))
                            .foregroundStyle(.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .accessibilityLabel("Main income")
                    }
                }

                if let sched = src.schedule {
                    HStack(spacing: 8) {
                        Text(frequencyLabel(sched.frequency))
                        Text("Starts \(dateMedium(sched.anchorDate))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if src.defaultAmount > 0 {
                Text(currency(src.defaultAmount))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens income editor. Swipe for actions.")
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        FrostCard {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .imageScale(.large)
                Text("No income sources yet")
                    .font(.headline)
                Text("Tap + to add your first income source.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func addSource() {
        // Stage in context (so the editor can bind) but present via Bool-based sheet to minimize identity churn.
        let sched = IncomeSchedule(frequency: .biweekly, anchorDate: Date())
        let new = IncomeSource(name: "", defaultAmount: 0, variable: false, schedule: sched)
        context.insert(new)
        draftNewSource = new
    }

    // MARK: - Main income toggling

    @ViewBuilder
    private func mainSwipeActions(for src: IncomeSource) -> some View {
        if let sched = src.schedule {
            if sched.isMain {
                Button {
                    Task { @MainActor in
                        sched.isMain = false
                        try? context.save()
                    }
                } label: {
                    Label("Clear Main", systemImage: "star.slash")
                }
                .tint(.gray)
            } else {
                Button {
                    Task { @MainActor in
                        // Ensure only one is main at a time
                        if let all: [IncomeSchedule] = try? context.fetch(FetchDescriptor<IncomeSchedule>()) {
                            for s in all { s.isMain = (s == sched) }
                        } else {
                            sched.isMain = true
                        }
                        try? context.save()
                    }
                } label: {
                    Label("Make Main", systemImage: "star")
                }
                .tint(.yellow)
            }
        }
    }

    @ViewBuilder
    private func mainContextMenu(for src: IncomeSource) -> some View {
        if let sched = src.schedule {
            if sched.isMain {
                Button {
                    Task { @MainActor in
                        sched.isMain = false
                        try? context.save()
                    }
                } label: {
                    Label("Clear Main Income", systemImage: "star.slash")
                }
            } else {
                Button {
                    Task { @MainActor in
                        if let all: [IncomeSchedule] = try? context.fetch(FetchDescriptor<IncomeSchedule>()) {
                            for s in all { s.isMain = (s == sched) }
                        } else {
                            sched.isMain = true
                        }
                        try? context.save()
                    }
                } label: {
                    Label("Make Main Income", systemImage: "star")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        IncomeSourcesView()
            .modelContainer(for: [IncomeSource.self, IncomeSchedule.self], inMemory: true)
    }
}
