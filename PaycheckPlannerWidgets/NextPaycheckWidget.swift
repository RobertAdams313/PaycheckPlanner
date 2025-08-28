import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Entry

struct NextPaycheckEntry: TimelineEntry {
    let date: Foundation.Date
    let payday: Foundation.Date
    let income: Decimal
    let billsTotal: Decimal
    let leftover: Decimal
    let topBills: [SharedAppGroup.Snapshot.TopBill]

    static let placeholder = NextPaycheckEntry(
        date: .now,
        payday: .now,
        income: 2500,
        billsTotal: 1800,
        leftover: 700,
        topBills: [
            .init(name: "Rent", amount: 1200, dueDate: .now),
            .init(name: "Electric", amount: 120, dueDate: .now)
        ]
    )
}

// MARK: - Provider

struct NextPaycheckProvider: AppIntentTimelineProvider {
    typealias Entry = NextPaycheckEntry
    typealias Intent = PaycheckDisplayConfigIntent

    func placeholder(in context: Context) -> Entry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        loadEntry() ?? .placeholder
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = loadEntry() ?? .placeholder
        // Refresh by next payday or in an hour, whichever is sooner.
        let refresh = min(entry.payday, Foundation.Date().addingTimeInterval(60 * 60))
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func loadEntry() -> Entry? {
        guard let snap = SharedAppGroup.load() else { return nil }
        return NextPaycheckEntry(
            date: Foundation.Date(),
            payday: snap.payday,
            income: snap.income,
            billsTotal: snap.billsTotal,
            leftover: snap.leftover,
            topBills: snap.topBills
        )
    }
}

// MARK: - View

struct NextPaycheckWidgetView: View {
    let entry: NextPaycheckProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: compact
        default: regular
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(intent: CyclePrevPaycheckIntent(), label: {
                Image(systemName: "chevron.backward")
            })
            Spacer()
            Text(entry.payday, style: .date)
                .font(.headline)
                .minimumScaleFactor(0.8)
            Spacer()
            Button(intent: CycleNextPaycheckIntent(), label: {
                Image(systemName: "chevron.forward")
            })
        }
        .font(.caption)
    }

    private var totals: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Income")
                Spacer()
                Text(format(entry.income)).monospacedDigit()
            }
            HStack {
                Text("Bills")
                Spacer()
                Text(format(entry.billsTotal)).monospacedDigit()
            }
            Divider().opacity(0.2)
            HStack {
                Text("Remaining").fontWeight(.semibold)
                Spacer()
                Text(format(entry.leftover)).monospacedDigit().fontWeight(.semibold)
            }
        }
        .font(.caption)
    }

    private var regular: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            totals

            if !entry.topBills.isEmpty {
                Divider().opacity(0.2)
                ForEach(entry.topBills.prefix(2), id: \.name) { bill in
                    let id = SharedAppGroup.billID(bill.name, bill.dueDate)
                    HStack {
                        Text(bill.name).lineLimit(1)
                        Spacer()
                        Text(format(bill.amount)).monospacedDigit()

                        // Use explicit label: initializer and an IntentParameter<String>
                        Button(
                            intent: MarkBillPaidIntent(billID: .init(title: displayName)),
                            label: {
                                Image(systemName: SharedAppGroup.isPaid(id) ? "checkmark.circle.fill" : "circle")
                            }
                        )
                        .buttonStyle(.borderless)
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(8)
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Text(format(entry.leftover))
                .font(.title2).bold().monospacedDigit()
            Text("Remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
    }

    private func format(_ amount: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

// MARK: - Widget

@main
struct NextPaycheckWidget: Widget {
    private let displayName: LocalizedStringResource = LocalizedStringResource("Next Paycheck")
    private let descriptionText: LocalizedStringResource = LocalizedStringResource("Shows your upcoming paycheck, bills, and remaining amount.")

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NextPaycheckWidget",
            intent: PaycheckDisplayConfigIntent.self,
            provider: NextPaycheckProvider()
        ) { entry in
            NextPaycheckWidgetView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource(stringLiteral: "Next Paycheck"))
        .description(LocalizedStringResource(stringLiteral: "Shows your upcoming paycheck, bills, and remaining amount."))

    }
}
private let displayName: LocalizedStringResource = LocalizedStringResource(stringLiteral: "Next Paycheck")
private let descriptionText: LocalizedStringResource = LocalizedStringResource(stringLiteral: "Shows your upcoming paycheck, bills, and remaining amount.")

// ...
