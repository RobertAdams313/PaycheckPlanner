//
//  BillsView.swift
//  PaycheckPlanner
//
//  Created by Rob on 8/24/25.
//  Updated on 9/2/25 – Card UI parity with PlanView; grouping toggle; fixes init label `existingBill:`
//  Updated on 9/4/25 – Mark-as-Paid per occurrence (long press), animated checkmark; compiles without external Haptics binding.
//

import SwiftUI
import SwiftData
import UIKit   // for UINotificationFeedbackGenerator

struct BillsView: View {
    @Environment(\.modelContext) private var context

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

    private func dueLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Due Today" }
        if cal.isDateInTomorrow(date) { return "Due Tomorrow" }
        if cal.isDateInYesterday(date) { return "Due Yesterday" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return "Due \(f.string(from: date))"
    }

    // MARK: - Local haptic (fallback if shared Haptics isn’t visible here)

    private func hapticSuccess() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }

    // MARK: - Shared Card Style

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

    // MARK: - Grouping

    private enum BillsGrouping: String, CaseIterable, Identifiable {
        case dueDate = "Due Date"
        case category = "Category"
        var id: String { rawValue }
    }

    // MARK: - SwiftData

    @Query(sort: \Bill.anchorDueDate, order: .forward)
    private var allBills: [Bill]

    // MARK: - State

    @AppStorage("billsGrouping") private var groupingRaw: String = BillsGrouping.dueDate.rawValue
    private var grouping: BillsGrouping {
        get { BillsGrouping(rawValue: groupingRaw) ?? .dueDate }
        set { groupingRaw = newValue.rawValue }
    }
    /// Binding for Picker (fixes “Generic parameter ‘SelectionValue’ could not be inferred” and “Cannot find $grouping”)
    private var groupingBinding: Binding<BillsGrouping> {
        Binding(
            get: { BillsGrouping(rawValue: groupingRaw) ?? .dueDate },
            set: { groupingRaw = $0.rawValue }
        )
    }

    @State private var showingAdd = false
    @State private var draftNewBill: Bill?

    // MARK: - Paid State (per-bill occurrence keyed by anchorDueDate)
    private func periodKey(for bill: Bill) -> Date {
        Calendar.current.startOfDay(for: bill.anchorDueDate)
    }
    private func isPaid(_ bill: Bill) -> Bool {
        MarkAsPaidService.isPaid(bill, periodKey: periodKey(for: bill), in: context)
    }
    @MainActor
    private func togglePaid(_ bill: Bill) {
        withAnimation(.snappy) {
            _ = MarkAsPaidService.togglePaid(bill, periodKey: periodKey(for: bill), in: context)
        }
    }

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
        let thisWeekEnd = (cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)).end
        let nextWeekEnd = (cal.date(byAdding: .weekOfYear, value: 1, to: thisWeekEnd)) ?? thisWeekEnd
        return allBills.filter { b in
            b.anchorDueDate >= thisWeekEnd && b.anchorDueDate < nextWeekEnd
        }
    }

    private var later: [Bill] {
        let cal = Calendar.current
        let now = Date()
        let nextWeekEnd = (cal.date(byAdding: .weekOfYear, value: 2, to: (cal.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)).end)) ?? now
        return allBills.filter { $0.anchorDueDate >= nextWeekEnd }
    }

    private var groupedByCategory: [Dictionary<String, [Bill]>.Element] {
        let groups = Dictionary(grouping: allBills) { $0.category.isEmpty ? "Uncategorized" : $0.category }
        return groups.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Text("Your Bills")
                .font(.title2.weight(.bold))
            Spacer()
            Button {
                hapticSuccess()
                showingAdd = true
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .labelStyle(.iconOnly)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingAdd) {
                AddOrEditBillView(existingBill: nil)
            }
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
                    Picker("Group by", selection: groupingBinding) {
                        ForEach(BillsGrouping.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    Label("Group", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Bill?.none) {
                    Label("Add Bill", systemImage: "plus")
                }
            }
        }
        .navigationDestination(for: Bill?.self) { bill in
            AddOrEditBillView(existingBill: bill)
        }
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
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bill.name.isEmpty ? "Untitled Bill" : bill.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 8) {
                                        Text(dueLabel(bill.anchorDueDate))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)

                                        if !bill.category.isEmpty {
                                            Text(bill.category)
                                                .font(.footnote.weight(.semibold))
                                                .padding(.horizontal, 8)
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

                                HStack(spacing: 8) {
                                    if isPaid(bill) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .imageScale(.large)
                                            .symbolRenderingMode(.hierarchical)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                    Text(ppCurrency(bill.amount))
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    // Long press anywhere on the row to toggle "Paid" for this occurrence
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                        hapticSuccess()
                        togglePaid(bill)
                    })
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No bills yet",
            systemImage: "list.bullet.rectangle",
            description: Text("Add a bill to see them organized by due date.")
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BillsView()
            .modelContainer(for: Bill.self, inMemory: true)
    }
}
