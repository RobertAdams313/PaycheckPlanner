import SwiftUI
import UniformTypeIdentifiers

struct ExportMenu: View {
    let bills: [Bill]
    let incomeSources: [IncomeSource]
    let schedules: [PaySchedule]
    @State private var csvURL: URL?
    var body: some View {
        Menu {
            Button("Export CSV") { exportCSV() }
            if let url = csvURL {
                ShareLink(item: url, preview: SharePreview("PaycheckPlanner.csv"))
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
    private func exportCSV() {
        let headers = "Type,Name,Amount,Recurrence,AnchorDate,RecurrenceEnd,Notes\n"
        var rows = ""
        let df = ISO8601DateFormatter()
        for b in bills {
            rows += "Bill,\(b.name),\(b.amount),\(b.recurrence.rawValue),\(df.string(from: b.anchorDueDate)),\(b.recurrenceEnd != nil ? df.string(from: b.recurrenceEnd!) : ""),\(b.notes ?? "")\n"
        }
        for s in schedules {
            rows += "Schedule,frequency=\(s.frequency.rawValue),base=\(s.paycheckAmount),anchor=\(df.string(from: s.anchorDate)),,\n"
        }
        for i in incomeSources {
            rows += "Income,\(i.name),\(i.defaultAmount),,,"
            rows += (i.notes ?? "") + "\n"
        }
        let data = Data((headers + rows).utf8)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PaycheckPlanner.csv")
        try? data.write(to: url)
        csvURL = url
    }
}
