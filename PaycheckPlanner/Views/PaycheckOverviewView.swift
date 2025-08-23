import SwiftUI

struct PaycheckOverviewView: View {
    let schedule: PaySchedule
    let bills: [Bill]
    let incomeSources: [IncomeSource]

    @AppStorage("defaultUpcomingCount") private var defaultUpcomingCount: Int = 6
    @State private var upcomingCount: Int = 6
    @State private var showPast: Bool = false

    var body: some View {
        let _ = { if upcomingCount != defaultUpcomingCount { upcomingCount = defaultUpcomingCount } }()
        let breakdowns = AllocationEngine.breakdowns(schedule: schedule, bills: bills, incomeSources: incomeSources, upcoming: upcomingCount)
        let pastBreakdowns = AllocationEngine.breakdownsPast(schedule: schedule, bills: bills, incomeSources: incomeSources, count: 6)

        List {
            Section {
                Toggle("Show past paychecks", isOn: $showPast)
            }
            if showPast {
                Section("Past paychecks") {
                    ForEach(pastBreakdowns) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.period.payday, style: .date).font(.subheadline)
                                Spacer()
                                Text(formatCurrency(item.leftover)).monospacedDigit().foregroundStyle(item.leftover >= 0 ? .green : .red)
                            }
                            Text("Income \(formatCurrency(item.income)) · Bills \(formatCurrency(item.totalBills))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Upcoming paychecks") {
                ForEach(breakdowns) { item in
                    NavigationLink(value: item.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.period.payday, style: .date).font(.headline)
                                Spacer()
                                Text("Leftover \(formatCurrency(item.leftover))").font(.headline).monospacedDigit().foregroundStyle(item.leftover >= 0 ? .green : .red)
                            }
                            HStack {
                                Label("Bills: \(item.allocated.count)", systemImage: "list.bullet").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text("Income \(formatCurrency(item.income)) · Bills \(formatCurrency(item.totalBills))").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationDestination(for: UUID.self) { _ in
                        PaycheckDetailView(breakdown: item, allSources: incomeSources, schedule: schedule)
                    }
                }
            }
            Section { Button("Load more paychecks") { upcomingCount += 6 } }
        }.listStyle(.insetGrouped)
    }
}
