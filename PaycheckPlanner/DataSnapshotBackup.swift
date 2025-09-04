//
//  DataSnapshotBackup.swift
//  PaycheckPlanner
//
//  JSON-based full data snapshots for backup/restore.
//  - encodeSnapshot / decodeSnapshot
//  - writeTemp (creates a temp .json file for share sheets)
//  - deleteAll(in:) to wipe-and-replace
//  - merge/replace restore helpers
//  - DataSnapshotBackup facade exposing .exportJSON(...) and .import(...)
//

import Foundation
import SwiftData

// MARK: - Public shim some callers may use

typealias Diction = [String: Any]

// MARK: - Snapshot Model

struct AppDataSnapshot: Codable {
    struct IncomeSourceCodable: Codable, Hashable {
        var name: String
        var defaultAmount: Decimal
        var variable: Bool
        // schedule (flattened)
        var scheduleFrequency: PayFrequency
        var scheduleAnchorDate: Date
        var semimonthlyFirstDay: Int
        var semimonthlySecondDay: Int
        var isMain: Bool
    }

    struct BillCodable: Codable, Hashable {
        var name: String
        var amount: Decimal
        var recurrence: BillRecurrence
        var anchorDueDate: Date
        var category: String
        var endDate: Date?
        var active: Bool
    }

    var incomes: [IncomeSourceCodable]
    var bills: [BillCodable]
    var createdAt: Date = Date()
}

// MARK: - Encoder / Decoder

func encodeSnapshot(_ snap: AppDataSnapshot) throws -> Data {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
    enc.dateEncodingStrategy = .secondsSince1970
    return try enc.encode(snap)
}

func decodeSnapshot(_ data: Data) throws -> AppDataSnapshot {
    let dec = JSONDecoder()
    dec.dateDecodingStrategy = .secondsSince1970
    return try dec.decode(AppDataSnapshot.self, from: data)
}

// MARK: - File helpers

@discardableResult
func writeTemp(_ data: Data, filename: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(filename)
    try data.write(to: url, options: .atomic)
    return url
}

/// "yyyy-MM-dd_HHmm-ss" (UTC) for filenames
func dateStamp(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    f.dateFormat = "yyyy-MM-dd_HHmm-ss"
    return f.string(from: date)
}

// MARK: - Snapshot builders

@MainActor
func makeSnapshot(context: ModelContext) -> AppDataSnapshot {
    let incomes: [IncomeSource] = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
    let schedules: [IncomeSchedule] = (try? context.fetch(FetchDescriptor<IncomeSchedule>())) ?? []
    let bills: [Bill] = (try? context.fetch(FetchDescriptor<Bill>())) ?? []

    var schedBySource: [ObjectIdentifier: IncomeSchedule] = [:]
    for s in schedules {
        if let src = s.source {
            schedBySource[ObjectIdentifier(src)] = s
        }
    }

    let incomesCodable: [AppDataSnapshot.IncomeSourceCodable] = incomes.map { src in
        let sch = schedBySource[ObjectIdentifier(src)]
        return .init(
            name: src.name,
            defaultAmount: src.defaultAmount,
            variable: src.variable,
            scheduleFrequency: sch?.frequency ?? .biweekly,
            scheduleAnchorDate: sch?.anchorDate ?? Date(),
            semimonthlyFirstDay: sch?.semimonthlyFirstDay ?? 1,
            semimonthlySecondDay: sch?.semimonthlySecondDay ?? 15,
            isMain: sch?.isMain ?? false
        )
    }

    let billsCodable: [AppDataSnapshot.BillCodable] = bills.map {
        .init(
            name: $0.name,
            amount: $0.amount,
            recurrence: $0.recurrence,
            anchorDueDate: $0.anchorDueDate,
            category: $0.category,
            endDate: $0.endDate,
            active: $0.active
        )
    }

    return .init(incomes: incomesCodable, bills: billsCodable, createdAt: Date())
}

// MARK: - Import / Restore

@MainActor
func restoreReplace(context: ModelContext, snapshot: AppDataSnapshot) throws {
    try deleteAll(in: context)
    try restoreMerge(context: context, snapshot: snapshot) // after wipe, merge == replace
}

/// Merge strategy:
/// - IncomeSources matched by `name` (case-insensitive); upsert schedule and fields.
/// - Bills matched by `(name, category, day(anchorDueDate))`; upsert fields.
@MainActor
func restoreMerge(context: ModelContext, snapshot: AppDataSnapshot) throws {
    // INCOMES
    var existingSources: [IncomeSource] = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
    func findSource(named name: String) -> IncomeSource? {
        existingSources.first { $0.name.compare(name, options: .caseInsensitive) == .orderedSame }
    }

    for c in snapshot.incomes {
        let src = findSource(named: c.name) ?? {
            let s = IncomeSource(name: c.name, defaultAmount: c.defaultAmount, variable: c.variable, schedule: nil)
            context.insert(s); existingSources.append(s); return s
        }()

        if let sched = src.schedule {
            sched.frequency = c.scheduleFrequency
            sched.anchorDate = c.scheduleAnchorDate
            sched.semimonthlyFirstDay = c.semimonthlyFirstDay
            sched.semimonthlySecondDay = c.semimonthlySecondDay
            sched.isMain = c.isMain
        } else {
            let sched = IncomeSchedule(
                source: src,
                frequency: c.scheduleFrequency,
                anchorDate: c.scheduleAnchorDate,
                semimonthlyFirstDay: c.semimonthlyFirstDay,
                semimonthlySecondDay: c.semimonthlySecondDay,
                isMain: c.isMain
            )
            context.insert(sched)
            src.schedule = sched
        }
        src.defaultAmount = c.defaultAmount
        src.variable = c.variable
    }

    // BILLS
    var existingBills: [Bill] = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
    let cal = Calendar(identifier: .gregorian)
    func billKey(_ name: String, _ category: String, _ date: Date) -> String {
        let d = cal.dateComponents([.day], from: date).day ?? 0
        return "\(name.lowercased())|\(category.lowercased())|\(d)"
    }
    var dict: [String: Bill] = [:]
    for b in existingBills { dict[billKey(b.name, b.category, b.anchorDueDate)] = b }

    for c in snapshot.bills {
        let key = billKey(c.name, c.category, c.anchorDueDate)
        if let b = dict[key] {
            b.amount = c.amount
            b.recurrence = c.recurrence
            b.anchorDueDate = c.anchorDueDate
            b.category = c.category
            b.endDate = c.endDate
            b.active = c.active
        } else {
            let b = Bill(
                name: c.name,
                amount: c.amount,
                recurrence: c.recurrence,
                anchorDueDate: c.anchorDueDate,
                category: c.category,
                endDate: c.endDate,
                active: c.active
            )
            context.insert(b)
            dict[key] = b
            existingBills.append(b)
        }
    }

    try context.save()
}

// MARK: - Delete all entities

@MainActor
func deleteAll(in context: ModelContext) throws {
    let allIncomeSources: [IncomeSource] = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
    let allSchedules: [IncomeSchedule] = (try? context.fetch(FetchDescriptor<IncomeSchedule>())) ?? []
    let allBills: [Bill] = (try? context.fetch(FetchDescriptor<Bill>())) ?? []

    for o in allSchedules { context.delete(o) }
    for o in allIncomeSources { context.delete(o) }
    for o in allBills { context.delete(o) }

    try context.save()
}

// MARK: - Convenience export helper (kept for direct callers)

@MainActor
func exportSnapshotFile(context: ModelContext) throws -> URL {
    let snap = makeSnapshot(context: context)
    let data = try encodeSnapshot(snap)
    let name = "PaycheckPlanner_Snapshot_\(dateStamp(snap.createdAt)).json"
    return try writeTemp(data, filename: name)
}

// MARK: - Facade expected by SettingsHostView

enum DataSnapshotBackup {
    enum ImportMode { case merge, replace }

    /// Exports a full-fidelity JSON snapshot to a temp file and returns its URL.
    @MainActor
    static func exportJSON(context: ModelContext) throws -> URL {
        let snap = makeSnapshot(context: context)
        let data = try encodeSnapshot(snap)
        let name = "PaycheckPlanner-Data-\(dateStamp(snap.createdAt)).json"
        return try writeTemp(data, filename: name)
    }

    /// Imports a snapshot from URL, either merging into existing data or replacing all data.
    @MainActor
    static func `import`(from url: URL, into context: ModelContext, mode: ImportMode) throws {
        let data = try Data(contentsOf: url)
        let snap = try decodeSnapshot(data)
        switch mode {
        case .merge:   try restoreMerge(context: context, snapshot: snap)
        case .replace: try restoreReplace(context: context, snapshot: snap)
        }
    }
}
