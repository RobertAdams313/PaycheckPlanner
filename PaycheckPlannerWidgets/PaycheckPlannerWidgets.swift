//
//  PaycheckPlannerWidgets.swift
//  PaycheckPlannerWidgets
//
//  Minimal widget (no AppIntents/buttons). iOS 16+.
//  Reads from SharedAppGroup.load()/loadSnapshots().
//

import SwiftUI
import WidgetKit

// MARK: - Display model

struct PayDisplay: Hashable {
    var periodTitle: String
    var incomeFormatted: String
    var billsFormatted: String
    var leftoverFormatted: String
    var overdueCount: Int
    var upcomingBills: [BillLine] = []

    struct BillLine: Hashable {
        var name: String
        var amountFormatted: String
        var isOverdue: Bool
        var dueDate: Date
    }
}

enum WidgetDisplayMode: String {
    case leftoverOnly, incomeVsBills, billsList
}

struct NextPaycheckEntry: TimelineEntry {
    let date: Date
    let display: PayDisplay
    let mode: WidgetDisplayMode
}

// MARK: - Snapshot -> Display

fileprivate func buildDisplay(from s: Snapshot) -> PayDisplay {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    let title = "Payday " + df.string(from: s.payday)

    let cur = NumberFormatter()
    cur.numberStyle = .currency
    cur.maximumFractionDigits = 2
    cur.minimumFractionDigits = 2
    func money(_ d: Decimal) -> String { cur.string(from: NSDecimalNumber(decimal: d)) ?? "$0.00" }

    let todayStart = Calendar.current.startOfDay(for: Date())
    let overdue = s.topBills.filter { bill in
        let id = SharedAppGroup.billID(bill.name, bill.dueDate)
        return bill.dueDate < todayStart && !SharedAppGroup.isPaid(id)
    }

    let lines: [PayDisplay.BillLine] = s.topBills
        .sorted { $0.dueDate < $1.dueDate }
        .compactMap { bill in
            let id = SharedAppGroup.billID(bill.name, bill.dueDate)
            guard !SharedAppGroup.isPaid(id) else { return nil }
            return .init(
                name: bill.name,
                amountFormatted: money(bill.amount),
                isOverdue: bill.dueDate < todayStart,
                dueDate: bill.dueDate
            )
        }

    return PayDisplay(
        periodTitle: title,
        incomeFormatted: money(s.incomeTotal + s.carryIn),
        billsFormatted: money(s.billsTotal),
        leftoverFormatted: money(s.remaining),
        overdueCount: overdue.count,
        upcomingBills: lines
    )
}

fileprivate func loadDisplay() -> PayDisplay {
    if let s = SharedAppGroup.load() { return buildDisplay(from: s) }
    if let s0 = SharedAppGroup.loadSnapshots().first { return buildDisplay(from: s0) }
    // Placeholder sample
    return PayDisplay(
        periodTitle: "Payday Sep 5",
        incomeFormatted: "$2,450.00",
        billsFormatted: "$1,210.00",
        leftoverFormatted: "$1,240.00",
        overdueCount: 1,
        upcomingBills: [
            .init(name: "Rent", amountFormatted: "$950.00", isOverdue: false, dueDate: Date().addingTimeInterval(86400)),
            .init(name: "Electric", amountFormatted: "$85.34", isOverdue: false, dueDate: Date().addingTimeInterval(2*86400)),
            .init(name: "Phone", amountFormatted: "$52.90", isOverdue: true,  dueDate: Date().addingTimeInterval(-86400))
        ]
    )
}

fileprivate func persistedMode() -> WidgetDisplayMode {
    let raw = SharedAppGroup.defaults.string(forKey: "pp_widget_mode_v1") ?? "leftoverOnly"
    return WidgetDisplayMode(rawValue: raw) ?? .leftoverOnly
}

// MARK: - Provider

struct NextPaycheckProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextPaycheckEntry {
        .init(date: .now, display: loadDisplay(), mode: .leftoverOnly)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPaycheckEntry) -> Void) {
        completion(.init(date: .now, display: loadDisplay(), mode: persistedMode()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPaycheckEntry>) -> Void) {
        let entry = NextPaycheckEntry(date: .now, display: loadDisplay(), mode: persistedMode())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - View

struct NextPaycheckWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextPaycheckEntry

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemMedium: medium
        case .systemLarge: large
        case .accessoryRectangular: accessoryRectangular
        case .accessoryInline: accessoryInline
        default: medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.display.periodTitle).font(.caption).foregroundStyle(.secondary)

            switch entry.mode {
            case .leftoverOnly:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leftover").font(.caption2).foregroundStyle(.secondary)
                    Text(entry.display.leftoverFormatted).font(.headline).bold()
                }
            case .incomeVsBills:
                VStack(alignment: .leading, spacing: 2) {
                    HStack { Text("Income"); Spacer(); Text(entry.display.incomeFormatted) }.font(.caption2)
                    HStack { Text("Bills");  Spacer(); Text(entry.display.billsFormatted)  }.font(.caption2)
                    Divider()
                    HStack {
                        Text("Leftover").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.display.leftoverFormatted).font(.subheadline).bold()
                    }
                }
            case .billsList:
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entry.display.upcomingBills.prefix(3), id: \.self) { line in
                        HStack { Text(line.name).lineLimit(1); Spacer(minLength: 6); Text(line.amountFormatted) }
                            .font(.caption2)
                            .overlay(alignment: .leading) {
                                if line.isOverdue { Circle().fill(.red).frame(width: 4, height: 4).offset(x: -6) }
                            }
                    }
                }
            }

            if entry.display.overdueCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill").imageScale(.small)
                    Text("\(entry.display.overdueCount) overdue").font(.caption2)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.clear }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.display.periodTitle).font(.caption).foregroundStyle(.secondary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Income").font(.caption2).foregroundStyle(.secondary)
                        Text(entry.display.incomeFormatted).font(.headline).bold()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bills").font(.caption2).foregroundStyle(.secondary)
                        Text(entry.display.billsFormatted).font(.headline).bold()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leftover").font(.caption2).foregroundStyle(.secondary)
                        Text(entry.display.leftoverFormatted).font(.headline).bold()
                    }
                }

                if entry.display.overdueCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("\(entry.display.overdueCount) overdue")
                    }
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
            }

            if entry.mode == .billsList {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.display.upcomingBills.prefix(4), id: \.self) { line in
                        HStack { Text(line.name).lineLimit(1); Spacer(minLength: 6); Text(line.amountFormatted) }
                            .font(.caption2)
                            .overlay(alignment: .leading) {
                                if line.isOverdue { Circle().fill(.red).frame(width: 5, height: 5).offset(x: -6) }
                            }
                    }
                }
                .frame(maxWidth: 160)
            }
        }
        .padding()
        .containerBackground(for: .widget) { Color.clear }
    }

    private var large: some View { VStack(alignment: .leading, spacing: 8) { medium } }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.display.periodTitle).font(.caption2).foregroundStyle(.secondary)
            HStack {
                Text("Lft:"); Text(entry.display.leftoverFormatted).bold()
                if entry.display.overdueCount > 0 { Spacer(minLength: 4); Text("⚠︎\(entry.display.overdueCount)") }
            }.font(.caption2)
        }
    }

    private var accessoryInline: some View {
        Text("Leftover \(entry.display.leftoverFormatted)")
    }
}

// MARK: - Widget

struct NextPaycheckWidget: Widget {
    let kind = "NextPaycheckWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPaycheckProvider()) { entry in
            NextPaycheckWidgetView(entry: entry)
        }
        .configurationDisplayName("Paycheck Planner")
        .description("See your payday, bills, leftover.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

@main
struct PaycheckPlannerWidgets: WidgetBundle {
    var body: some Widget {
        NextPaycheckWidget()
    }
}
