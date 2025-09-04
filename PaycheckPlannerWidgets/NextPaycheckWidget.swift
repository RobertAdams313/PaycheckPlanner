//
//  NextPaycheckWidget.swift
//  PaycheckPlannerWidgets
//

import Foundation
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Entry

struct NextPaycheckEntry: TimelineEntry {
    let date: Date
    let payday: Date
    let income: Decimal
    let billsTotal: Decimal
    let leftover: Decimal
    let topBills: [TopBill]

    static let placeholder = NextPaycheckEntry(
        date: Date(),
        payday: Date(),
        income: 0,
        billsTotal: 0,
        leftover: 0,
        topBills: []
    )
}

// MARK: - Provider

struct NextPaycheckProvider: AppIntentTimelineProvider {
    typealias Intent = PaycheckDisplayConfigIntent
    typealias Entry = NextPaycheckEntry

    func placeholder(in context: Context) -> Entry { .placeholder }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        loadEntry() ?? .placeholder
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = loadEntry() ?? .placeholder
        // refresh sooner of: one hour from now or the payday
        let refresh = min(entry.payday, Date().addingTimeInterval(60 * 60))
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    // MARK: - Load from shared snapshot

    private func loadEntry() -> Entry? {
        // Assuming you have a SharedAppGroup.load() that returns Snapshot
        if let snap = SharedAppGroup.load() {
            return Entry(
                date: Date(),
                payday: snap.payday,
                income: snap.incomeTotal,
                billsTotal: snap.billsTotal,
                leftover: snap.remaining,
                topBills: snap.topBills
            )
        }
        return nil
    }
}

// MARK: - View

struct NextPaycheckWidgetView: View {
    var entry: NextPaycheckEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next payday")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(entry.payday, style: .date)
                .font(.headline)

            HStack {
                Text("Leftover")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(format(entry.leftover))
                    .bold()
                    .monospacedDigit()
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
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

// MARK: - Widget

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
