import WidgetKit
import SwiftUI
import AppIntents

struct NextPaycheckEntry: TimelineEntry {
    let date: Date
    let payday: Date
    let income: Decimal
    let billsTotal: Decimal
    let leftover: Decimal
    let topBills: [SharedAppGroup.Snapshot.TopBill]
    static let placeholder = NextPaycheckEntry(date: .now, payday: .now, income: 0, billsTotal: 0, leftover: 0, topBills: [])
}

// Use AppIntentTimelineProvider so the widget can be configured with an intent.
struct NextPaycheckProvider: AppIntentTimelineProvider {
    typealias Intent = PaycheckDisplayConfigIntent
    typealias Entry = NextPaycheckEntry

    func placeholder(in context: Context) -> Entry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        // let mode = configuration.mode ?? .leftoverOnly  // use if you branch on mode later
        return loadEntry() ?? .placeholder
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        // let mode = configuration.mode ?? .leftoverOnly
        let entry = loadEntry() ?? .placeholder
        let refresh = min(entry.payday, Date().addingTimeInterval(60*60))
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    // ... loadEntry() unchanged ...

    private func loadEntry() -> Entry? {
        if let snap = SharedAppGroup.load() {
            return Entry(date: Date(),
                         payday: snap.payday,
                         income: snap.income,
                         billsTotal: snap.billsTotal,
                         leftover: snap.leftover,
                         topBills: snap.topBills)
        }
        return nil
    }
}

struct NextPaycheckWidgetView: View {
    var entry: NextPaycheckEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next payday").font(.caption).foregroundStyle(.secondary)
            Text(entry.payday, style: .date).font(.headline)

            HStack {
                Text("Leftover").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(format(entry.leftover)).bold().monospacedDigit()
                    .foregroundStyle(entry.leftover >= 0 ? .green : .red)
            }

            HStack {
                Button(intent: CyclePrevPaycheckIntent()) { Image(systemName: "chevron.backward") }
                Spacer()
                Button(intent: CycleNextPaycheckIntent()) { Image(systemName: "chevron.forward") }
            }
            .font(.caption)

            if !entry.topBills.isEmpty {
                Divider().opacity(0.2)
                ForEach(entry.topBills.prefix(2), id: \.name) { b in
                    let id = SharedAppGroup.billID(b.name, b.dueDate)
                    HStack {
                        Text(b.name).lineLimit(1)
                        Spacer()
                        Text(format(b.amount)).monospacedDigit()
                        Button(intent: MarkBillPaidIntent(billID: id, paid: !SharedAppGroup.isPaid(id))) {
                            Image(systemName: SharedAppGroup.isPaid(id) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .padding(12)
    }
    private func format(_ value: Decimal) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = .current
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

struct NextPaycheckWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NextPaycheckWidget",
            intent: PaycheckDisplayConfigIntent.self,
            provider: NextPaycheckProvider()
        ) { entry in
            NextPaycheckWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Paycheck")
        .description("Shows your next payday, leftover, and top bills.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}
