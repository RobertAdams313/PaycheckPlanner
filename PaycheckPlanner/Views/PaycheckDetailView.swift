//
//  PaycheckDetailView.swift
//  PaycheckPlanner
//
//  Restored “classic” layout (screenshot style) with Card-like sections.
//  Uses current engine types (CombinedPeriod, CombinedBreakdown, AllocatedBillLine).
//
//  Swap-in CardKit: replace `.ppCard()` with your CardKit modifier.
//

import SwiftUI
import SwiftData

// MARK: - Helpers

private func sod(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

private func currency(_ d: Decimal) -> String {
    let n = NSDecimalNumber(decimal: d)
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    f.minimumFractionDigits = 2
    f.locale = .current
    return f.string(from: n) ?? "$0.00"
}

private func dateMedium(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: date)
}

private func dateShortDay(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f.string(from: date)
}

private func frequencyLabel(_ freq: PayFrequency) -> String {
    switch freq {
    case .once:         return "One-time"
    case .weekly:       return "Weekly"
    case .biweekly:     return "Biweekly"
    case .semimonthly:  return "Semi-monthly"
    case .monthly:      return "Monthly"
    }
}

// MARK: - View

struct PaycheckDetailView: View {
    let payday: Date

    @Environment(\.modelContext) private var context
    @Query(sort: \IncomeSchedule.anchorDate, order: .forward) private var schedules: [IncomeSchedule]
    @Query(sort: \Bill.anchorDueDate, order: .forward) private var bills: [Bill]

    private var breakdown: CombinedBreakdown? {
        // Build starting 1 day before to avoid a [payday, payday] zero-length segment.
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -1, to: payday) ?? payday

        let all = CombinedPayEventsEngine.upcomingBreakdowns(
            context: context,
            count: 16,
            from: from,
            calendar: cal
        )

        // Prefer the period that *contains* the target payday in (start, end].
        if let hit = all.first(where: { p in
            // strict after start, inclusive of end (engine uses (start, end])
            (p.period.start < payday) && (payday <= p.period.end)
        }) {
            return hit
        }

        // Fallback: match by same-day end, but ignore zero-length periods.
        if let byEnd = all.first(where: { sod($0.period.end) == sod(payday) && $0.period.start < $0.period.end }) {
            return byEnd
        }

        // Last resort: first non-zero period.
        return all.first(where: { $0.period.start < $0.period.end }) ?? all.first
    }


    var body: some View {
        Group {
            if let b = breakdown {
                content(for: b)
            } else {
                missingState
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(for b: CombinedBreakdown) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Big header range like screenshot (Sep 29 – Oct 13, 2025)
                Text("\(dateMedium(b.period.start)) – \(dateMedium(b.period.end))")
                    .font(.largeTitle.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.horizontal, 16)

                // Metrics card (centered columns + carry-in row divider)
                VStack(spacing: 0) {
                    HStack(spacing: 24) {
                        metricColumn(title: "Income", value: currency(b.incomeTotal))
                        metricColumn(title: "Bills", value: currency(b.billsTotal))
                        metricColumn(title: "Remaining", value: currency(b.incomeTotal + b.carryIn - b.billsTotal))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                    Divider().padding(.horizontal, 16)

                    HStack {
                        Text("Carry-in")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(currency(b.carryIn))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .ppCard()
                .padding(.horizontal, 16)

                // Incomes card
                if !b.period.incomes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Incomes")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        VStack(spacing: 0) {
                            ForEach(b.period.incomes) { inc in
                                incomeRow(inc)
                                if inc.id != b.period.incomes.last?.id {
                                    Divider().opacity(0.25)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.clear)
                    }
                    .ppCard()
                    .padding(.horizontal, 16)
                }

                // Bills card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bills")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    if b.items.isEmpty {
                        Text("No bills allocated for this paycheck.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(b.items, id: \.id) { line in
                                billRow(line)
                                if line.id != b.items.last?.id {
                                    Divider().opacity(0.25)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                }
                .ppCard()
                .padding(.horizontal, 16)

                // Subtle ledger (like your faded list under Bills)
                ledgerSummary(b)
                    .padding(.horizontal, 24)
                    .padding(.top, -8)

                // Remaining card at bottom
                HStack {
                    Text("Remaining")
                        .font(.headline)
                    Spacer()
                    Text(currency(b.incomeTotal + b.carryIn - b.billsTotal))
                        .font(.headline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .ppCard()
                .padding(.horizontal, 16)

                Spacer(minLength: 24)
            }
            .padding(.bottom, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty

    private var missingState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No data for this paycheck")
                .font(.headline)
            Text("Add an income schedule and some bills to see allocations.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Pieces

    @ViewBuilder
    private func metricColumn(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func incomeRow(_ inc: PeriodIncome) -> some View {
        // Find this income’s schedule to display its frequency subtitle.
        let freqText: String = {
            if let s = schedules.first(where: { $0.source?.persistentModelID == inc.source.persistentModelID }) {
                return frequencyLabel(s.frequency)
            }
            return ""
        }()

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(inc.source.name.isEmpty ? "Income" : inc.source.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if !freqText.isEmpty {
                    Text(freqText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            Text(currency(inc.amount))
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(inc.source.name), \(currency(inc.amount))")
    }

    @ViewBuilder
    private func billRow(_ line: AllocatedBillLine) -> some View {
        let recurrence = frequencyLabel({
            switch line.bill.recurrence {
            case .once:         return .once
            case .weekly:       return .weekly
            case .biweekly:     return .biweekly
            case .semimonthly:  return .semimonthly
            case .monthly:      return .monthly
            }
        }())

        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(line.bill.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(recurrence)
                    Text("•")
                    Text("due \(dateShortDay(line.bill.anchorDueDate))")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(currency(line.total))
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.bill.name), \(currency(line.total))")
    }

    // MARK: - Ledger (faded)

    @ViewBuilder
    private func ledgerSummary(_ b: CombinedBreakdown) -> some View {
        let start = b.incomeTotal + b.carryIn
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Start (Income + Carry-in)")
                Spacer()
                Text(currency(start))
            }
            ForEach(b.items, id: \.id) { line in
                HStack {
                    Text("–  \(line.bill.name) — \(dateShortDay(line.bill.anchorDueDate))")
                    Spacer()
                    Text("− \(currency(line.total))")
                }
            }
            HStack {
                Text("=  Remaining")
                Spacer()
                Text(currency(b.incomeTotal + b.carryIn - b.billsTotal))
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .opacity(0.6)
    }
}

// MARK: - Simple Card look (swap to CardKit by replacing the modifier)

private struct PPCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

private extension View {
    /// Replace `.ppCard()` with your CardKit modifier (e.g., `.cardContainer()`).
    func ppCard() -> some View { self.modifier(PPCard()) }
}
