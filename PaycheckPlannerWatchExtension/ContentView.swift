import SwiftUI

struct BillRow: View {
    let name: String
    let amount: Decimal
    let dueDate: Date
    @State private var paid: Bool = false
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name).font(.caption)
                Text(dueDate, style: .date).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: {
                let id = SharedAppGroup.billID(name, dueDate)
                paid.toggle()
                SharedAppGroup.setPaid(id, paid)
            }) {
                Image(systemName: paid ? "checkmark.circle.fill" : "circle")
            }
        }.onAppear {
            paid = SharedAppGroup.isPaid(SharedAppGroup.billID(name, dueDate))
        }
    }
}

struct ContentView: View {
    let snap = SharedAppGroup.load()
    let list = SharedAppGroup.loadList()
    var body: some View {
        List {
            if let s = snap {
                Section("Next Paycheck") {
                    HStack { Text(s.payday, style: .date); Spacer(); Text(format(s.leftover)).monospacedDigit() }
                }
                if !s.topBills.isEmpty {
                    Section("Top Bills") {
                        ForEach(s.topBills, id: \.name) { b in
                            BillRow(name: b.name, amount: b.amount, dueDate: b.dueDate)
                        }
                    }
                }
            }
            if list.count > 1 {
                Section("Upcoming") {
                    ForEach(Array(list.dropFirst().prefix(1)), id: \.payday) { item in
                        HStack { Text(item.payday, style: .date); Spacer(); Text(format(item.leftover)).monospacedDigit() }
                    }
                }
            }
        }
    }
    private func format(_ value: Decimal) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = .current
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}
