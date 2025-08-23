import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PaySchedule.anchorDate) private var schedules: [PaySchedule]
    @Query(sort: \Bill.name) private var bills: [Bill]
    @Query(sort: \IncomeSource.name) private var incomeSources: [IncomeSource]

    @State private var showAddBill = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            if let schedule = schedules.first {
                PaycheckOverviewView(schedule: schedule, bills: bills, incomeSources: incomeSources)
                    .navigationTitle("Paycheck Planner")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { ExportMenu(bills: bills, incomeSources: incomeSources, schedules: schedules) }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button { showAddBill = true } label: { Label("Add Bill", systemImage: "plus.circle.fill") }
                            Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                        }
                    }
                    .sheet(isPresented: $showAddBill) { AddOrEditBillView() }
                    .sheet(isPresented: $showSettings) { SettingsView(schedule: schedule) }
                    .onAppear {
                        let breakdowns = AllocationEngine.breakdowns(schedule: schedule, bills: bills, incomeSources: incomeSources, upcoming: 2)
                        if let b = breakdowns.first {
                            let top = b.allocated.prefix(3).map { SharedAppGroup.Snapshot.TopBill(name: $0.bill.name, amount: $0.bill.amount, dueDate: $0.dueDate) }
                            let snap = SharedAppGroup.Snapshot(payday: b.period.payday, income: b.income, billsTotal: b.totalBills, leftover: b.leftover, topBills: Array(top))
                            SharedAppGroup.save(snapshot: snap)
                            SharedAppGroup.saveList(snapshots: breakdowns.map { b in
                                let top2 = b.allocated.prefix(3).map { SharedAppGroup.Snapshot.TopBill(name: $0.bill.name, amount: $0.bill.amount, dueDate: $0.dueDate) }
                                return SharedAppGroup.Snapshot(payday: b.period.payday, income: b.income, billsTotal: b.totalBills, leftover: b.leftover, topBills: Array(top2))
                            })
                        }
                        WidgetCenter.shared.reloadAllTimelines()
                    }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock").font(.system(size: 56)).padding(.bottom, 8)
                    Text("Set up your pay schedule").font(.title2).bold()
                    Text("We'll use this to determine which bills fall into each paycheck.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Button {
                        let s = PaySchedule(); context.insert(s)
                    } label: { Text("Get Started").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .padding()
                .navigationTitle("Paycheck Planner")
            }
        }
    }
}
