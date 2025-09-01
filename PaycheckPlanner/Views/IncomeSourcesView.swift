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

/// Income sources grouped (recurring / one-time upcoming / one-time past).
/// Adds Calendar push toggle & “Push Next N Paydays” to toolbar.
struct IncomeSourcesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSource.name, order: .forward) private var incomes: [IncomeSource]
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]

    @AppStorage("showPastOneTimeIncome") private var showPastOneTimeIncome: Bool = false
    @AppStorage("pushPaydaysToCalendar") private var pushPaydaysToCalendar: Bool = false
    @AppStorage("paydayAlertDaysBefore") private var paydayAlertDaysBefore: Int = 1
    @AppStorage("planPeriodCount") private var planCount: Int = 4

    // MARK: - Buckets
    private var recurring: [IncomeSource] {
        incomes.filter { $0.schedule?.frequency != .once }
    }

    private var upcomingOneTime: [IncomeSource] {
        let today = Calendar.current.startOfDay(for: Date())
        return incomes.filter { s in
            guard s.schedule?.frequency == .once, let d = s.schedule?.anchorDate else { return false }
            return Calendar.current.startOfDay(for: d) >= today
        }
    }

    private var pastOneTime: [IncomeSource] {
        let today = Calendar.current.startOfDay(for: Date())
        return incomes.filter { s in
            guard s.schedule?.frequency == .once, let d = s.schedule?.anchorDate else { return false }
            return Calendar.current.startOfDay(for: d) < today
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !recurring.isEmpty {
                    Section("Recurring") {
                        ForEach(recurring) { s in sourceRow(s) }
                    }
                }

                if !upcomingOneTime.isEmpty {
                    Section("Upcoming (One-time)") {
                        ForEach(upcomingOneTime) { s in sourceRow(s) }
                    }
                }

                if showPastOneTimeIncome, !pastOneTime.isEmpty {
                    Section("Past (One-time)") {
                        ForEach(pastOneTime) { s in sourceRow(s) }
                    }
                }
            }
            .navigationTitle("Income")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle("Push Paydays to Calendar", isOn: $pushPaydaysToCalendar)
                        Stepper("Alert \(paydayAlertDaysBefore) day(s) before", value: $paydayAlertDaysBefore, in: 0...14)
                        Divider()
                        Button("Push Next \(max(planCount, 1)) Paydays") { pushPaydaysNow() }
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                }
            }
            .onChange(of: pushPaydaysToCalendar) { newVal in
                if newVal { pushPaydaysNow() }
            }
        }
    }

    @ViewBuilder
    private func sourceRow(_ s: IncomeSource) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name.isEmpty ? "Untitled" : s.name)
                if let sch = s.schedule {
                    Text("\(sch.frequency.displayName) • \(sch.anchorDate, style: .date)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("No schedule")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(s.defaultAmount.currencyString)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Calendar push (paydays)
    private func pushPaydaysNow() {
        let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: max(planCount, 1))
        let paydays = periods.map(\.payday)
        Task {
            do {
                for d in paydays {
                    try await CalendarManager.shared.addPaydayEvent(date: d, alertDaysBefore: paydayAlertDaysBefore)
                }
            } catch {
                print("Push paydays failed: \(error)")
            }
        }
    }
}
