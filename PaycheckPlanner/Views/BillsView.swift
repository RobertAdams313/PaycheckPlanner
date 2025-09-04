//
//  BillsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Card UI parity with PlanView; grouping toggle; fixes init label `existingBill:`
//

import SwiftUI
import SwiftData

// MARK: - Utilities

/// Distinct name to avoid clashing with any global currency helpers.
private func ppCurrency(_ d: Decimal) -> String {
    let n = NSDecimalNumber(decimal: d)
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    return f.string(from: n) ?? "$0.00"
}

private func dueSubtitle(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "Due Today" }
    if cal.isDateInTomorrow(date) { return "Due Tomorrow" }
    if cal.isDateInYesterday(date) { return "Due Yesterday" }
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return "Due \(f.string(from: date))"
}

// MARK: - Grouping

private enum BillsGrouping: String, CaseIterable, Identifiable {
    case dueDate = "Due Date"
    case category = "Category"
    var id: String { rawValue }
}

// MARK: - View

struct BillsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var allBills: [Bill]

    @State private var grouping: BillsGrouping = .dueDate
    @State private var draftNewBill: Bill?

    // MARK: - Time buckets

    private var overdue: [Bill] {
        let now = Date()
        return allBills.filter { $0.anchorDueDate < now }
    }

    private var dueToday: [Bill] {
        let now = Date()
        return allBills.filter { Calendar.current.isDateInToday($0.anchorDueDate) && $0.anchorDueDate >= now }
    }

    private var thisWeek: [Bill] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        let endOfWeek = weekInterval.end
        return allBills.filter { b in
            b.anchorDueDate > startOfToday &&
            b.anchorDueDate < endOfWeek &&
            !Calendar.current.isDateInToday(b.anchorDueDate)
        }
    }

    private var nextWeek: [Bill] {
        let cal = Calendar.current
        let now = Date()
        let thisWeekInterval = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        guard let nextWeekStart = cal.date(byAdding: .weekOfYear, value: 1, to: thisWeekInterval.start),
              let nextWeekInterval = cal.dateInterval(of: .weekOfYear, for: nextWeekStart)
        else { return [] }
        return allBills.filter { b in
            b.anchorDueDate >= nextWeekInterval.start && b.anchorDueDate < nextWeekInterval.end
        }
    }

    private var later: [Bill] {
        let cal = Calendar.current
        let now = Date()
        let thisWeekInterval = cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        guard let nextWeekStart = cal.date(byAdding: .weekOfYear, value: 1, to: thisWeekInterval.start),
              let nextWeekInterval = cal.dateInterval(of: .weekOfYear, for: nextWeekStart)
        else { return [] }
        return allBills.filter { b in b.anchorDueDate >= nextWeekInterval.end }
    }

    // MARK: - Category grouping

    private var groupedByCategory: [(key: String, value: [Bill])] {
        let dict = Dictionary(grouping: allBills, by: { $0.category.isEmpty ? "Uncategorized" : $0.category })
        return dict
            .map { (key: $0.key, value: $0.value.sorted(by: { $0.anchorDueDate < $1.anchorDueDate })) }
            .sorted {
                ($0.value.first?.anchorDueDate ?? .distantFuture) < ($1.value.first?.anchorDueDate ?? .distantFuture)
            }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                headerBar
                switch grouping {
                case .dueDate:   dueDateBuckets
                case .category:  categoryBuckets
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Group by", selection: $grouping) {
                        ForEach(BillsGrouping.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label("Group", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { addBill() } label: {
                    Label("Add Bill", systemImage: "plus")
                }
            }
        }
        // IMPORTANT: Your BillEditorView requires `existingBill:` label.
        .navigationDestination(for: Bill.self) { bill in
            BillEditorView(existingBill: bill)
        }
        .sheet(item: $draftNewBill) { newBill in
            NavigationStack {
                BillEditorView(existingBill: newBill)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var headerBar: some View {
        HStack {
            Text("Your bills")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(allBills.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("Total bills")
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var dueDateBuckets: some View {
        if !overdue.isEmpty { section(title: "Overdue", bills: overdue) }
        if !dueToday.isEmpty { section(title: "Today", bills: dueToday) }
        if !thisWeek.isEmpty { section(title: "This Week", bills: thisWeek) }
        if !nextWeek.isEmpty { section(title: "Next Week", bills: nextWeek) }
        if !later.isEmpty { section(title: "Later", bills: later) }

        if overdue.isEmpty && dueToday.isEmpty && thisWeek.isEmpty && nextWeek.isEmpty && later.isEmpty {
            emptyState
        }
    }

    @ViewBuilder
    private var categoryBuckets: some View {
        if groupedByCategory.isEmpty {
            emptyState
        } else {
            ForEach(groupedByCategory, id: \.key) { group in
                section(title: group.key, bills: group.value)
            }
        }
    }

    private func section(title: String, bills: [Bill]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            VStack(spacing: 12) {
                ForEach(bills) { bill in
                    NavigationLink(value: bill) {
                        FrostCard {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bill.name.isEmpty ? "Untitled Bill" : bill.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    HStack(spacing: 8) {
                                        Text(dueSubtitle(bill.anchorDueDate))
                                            .foregroundStyle(.secondary)
                                            .font(.caption)

                                        if !bill.category.isEmpty {
                                            Text(bill.category)
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    Capsule(style: .continuous)
                                                        .fill(Color.primary.opacity(0.06))
                                                )
                                                .overlay(
                                                    Capsule(style: .continuous)
                                                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                                                )
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer(minLength: 8)

                                Text(ppCurrency(bill.amount))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        FrostCard {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .imageScale(.large)
                Text("No bills to show")
                    .font(.headline)
                Text("Tap + to add your first bill.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func addBill() {
        // Memberwise order per your model: name, amount, anchorDueDate, category
        let new = Bill(
            name: "",
            amount: 0,
            anchorDueDate: Date(),
            category: ""
        )
        context.insert(new)
        draftNewBill = new
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BillsView()
            .modelContainer(for: Bill.self, inMemory: true)
    }
}
