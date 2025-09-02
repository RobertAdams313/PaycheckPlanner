//
//  IncomeSourcesView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Card UI parity; explicit NavigationLink(destination:) to avoid value-based routing stalls
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

/// Frosted blur-card (shared)
private struct FrostCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(src.name.isEmpty ? "Untitled Income" : src.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        IncomeSourcesView()
            .modelContainer(for: [IncomeSource.self, IncomeSchedule.self], inMemory: true)
    }
}
