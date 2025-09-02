//
//  MigrationDirection.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/1/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  DataMigrator.swift
//  PaycheckPlanner
//
//  Copies SwiftData records between the Local and iCloud containers.
//  Scope: IncomeSource + IncomeSchedule (linked both ways), PaySchedule, and Bill.
//  Duplicate-aware, no destructive overwrites.
//
//  Uses day-precision for date identity. Safe defaults for CloudKit.
//  If you later add more models or stable UUIDs, extend the keys below.
//

import Foundation
import SwiftData

enum MigrationDirection: String, CaseIterable, Identifiable {
    case localToCloud
    case cloudToLocal

    var id: String { rawValue }
    var title: String {
        switch self {
        case .localToCloud: return "Local → iCloud"
        case .cloudToLocal: return "iCloud → Local"
        }
    }
}

struct MigrationReport: Sendable {
    var copiedIncomeSources: Int
    var copiedIncomeSchedules: Int
    var copiedPaySchedules: Int
    var copiedBills: Int
    var skippedDuplicates: Int
}

@MainActor
enum DataMigrator {

    /// Run the migration for supported models.
    /// - Returns: A summary report.
    static func migrate(direction: MigrationDirection, hub: StoreHub = .shared) throws -> MigrationReport {
        let (srcCtx, dstCtx) = contexts(direction: direction, hub: hub)

        // Fetch source models
        let srcIncomeSources   = try srcCtx.fetch(FetchDescriptor<IncomeSource>())
        let srcIncomeSchedules = try srcCtx.fetch(FetchDescriptor<IncomeSchedule>())
        let srcPaySchedules    = try srcCtx.fetch(FetchDescriptor<PaySchedule>())
        let srcBills           = try srcCtx.fetch(FetchDescriptor<Bill>())

        // Fetch destination for duplicate checks
        let dstIncomeSources   = try dstCtx.fetch(FetchDescriptor<IncomeSource>())
        let dstIncomeSchedules = try dstCtx.fetch(FetchDescriptor<IncomeSchedule>())
        let dstPaySchedules    = try dstCtx.fetch(FetchDescriptor<PaySchedule>())
        let dstBills           = try dstCtx.fetch(FetchDescriptor<Bill>())

        // MARK: - Identity keys (best-effort without a UUID field)

        // Decimal → String (stable)
        func decKey(_ d: Decimal) -> String { NSDecimalNumber(decimal: d).stringValue }

        // Dates at start-of-day for identity
        let cal = Calendar(identifier: .gregorian)
        func sod(_ d: Date) -> Date { cal.startOfDay(for: d) }

        // IncomeSource identity: (name.lowercased(), defaultAmount, variable)
        func key(_ s: IncomeSource) -> String {
            let nameKey = s.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return "is|name:\(nameKey)|amt:\(decKey(s.defaultAmount))|var:\(s.variable)"
        }

        // PaySchedule identity: (frequency, anchorDate@SOD, semimonthly d1/d2)
        func key(_ p: PaySchedule) -> String {
            let d = sod(p.anchorDate).timeIntervalSince1970
            return "ps|freq:\(p.frequency.rawValue)|date:\(d)|semi:\(p.semimonthlyFirstDay)-\(p.semimonthlySecondDay)"
        }

        // IncomeSchedule identity: (owner IncomeSource key + schedule fields)
        func key(_ sch: IncomeSchedule) -> String {
            let ownerKey = sch.source.map(key) ?? "nosrc"
            let d = sod(sch.anchorDate).timeIntervalSince1970
            return "sch|\(ownerKey)|freq:\(sch.frequency.rawValue)|date:\(d)|semi:\(sch.semimonthlyFirstDay)-\(sch.semimonthlySecondDay)"
        }

        // Bill identity: (name.lowercased(), amount, recurrence, due@SOD, category.lowercased())
        func key(_ b: Bill) -> String {
            let nameKey = b.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let catKey  = b.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let d = sod(b.anchorDueDate).timeIntervalSince1970
            return "bill|name:\(nameKey)|amt:\(decKey(b.amount))|rec:\(b.recurrence.rawValue)|date:\(d)|cat:\(catKey)"
        }

        // Destination key sets
        var dstISKeys  = Set(dstIncomeSources.map(key))
        var dstPSKeys  = Set(dstPaySchedules.map(key))
        var dstSchKeys = Set(dstIncomeSchedules.map(key))
        var dstBKeys   = Set(dstBills.map(key))

        // For reusing created IncomeSources when multiple schedules reference the same one
        var createdIncomeSourceByKey: [String: IncomeSource] = [:]

        var copiedIS  = 0
        var copiedSch = 0
        var copiedPS  = 0
        var copiedB   = 0
        var skipped   = 0

        // MARK: 1) Copy IncomeSource
        for isrc in srcIncomeSources {
            let k = key(isrc)
            if dstISKeys.contains(k) {
                skipped += 1
                continue
            }
            let d = IncomeSource(
                name: isrc.name,
                defaultAmount: isrc.defaultAmount,
                variable: isrc.variable
            )
            dstCtx.insert(d)
            createdIncomeSourceByKey[k] = d
            dstISKeys.insert(k)
            copiedIS += 1
        }

        // Build a lookup to find destination IncomeSource for a given source IncomeSource
        let destAllSources = try dstCtx.fetch(FetchDescriptor<IncomeSource>())
        func destSource(for src: IncomeSource) -> IncomeSource? {
            let k = key(src)
            return createdIncomeSourceByKey[k] ?? destAllSources.first { key($0) == k }
        }

        // MARK: 2) Copy IncomeSchedule (and link both sides)
        for s in srcIncomeSchedules {
            let k = key(s)
            if dstSchKeys.contains(k) {
                skipped += 1
                continue
            }
            guard let srcOwner = s.source, let destOwner = destSource(for: srcOwner) else {
                // No valid owner → skip
                skipped += 1
                continue
            }
            let sch = IncomeSchedule(
                source: destOwner,
                frequency: s.frequency,
                anchorDate: sod(s.anchorDate),
                semimonthlyFirstDay: s.semimonthlyFirstDay,
                semimonthlySecondDay: s.semimonthlySecondDay
            )
            // Link inverse explicitly (robust even if only one side declares the inverse)
            destOwner.schedule = sch

            dstCtx.insert(sch)
            dstSchKeys.insert(k)
            copiedSch += 1
        }

        // MARK: 3) Copy PaySchedule
        for ps in srcPaySchedules {
            let k = key(ps)
            if dstPSKeys.contains(k) {
                skipped += 1
                continue
            }
            let p = PaySchedule(
                frequency: ps.frequency,
                anchorDate: sod(ps.anchorDate),
                semimonthlyFirstDay: ps.semimonthlyFirstDay,
                semimonthlySecondDay: ps.semimonthlySecondDay
            )
            dstCtx.insert(p)
            dstPSKeys.insert(k)
            copiedPS += 1
        }

        // MARK: 4) Copy Bill
        for b in srcBills {
            let k = key(b)
            if dstBKeys.contains(k) {
                skipped += 1
                continue
            }
            let nb = Bill(
                name: b.name,
                amount: b.amount,
                recurrence: b.recurrence,
                anchorDueDate: sod(b.anchorDueDate),
                category: b.category
            )
            dstCtx.insert(nb)
            dstBKeys.insert(k)
            copiedB += 1
        }

        try dstCtx.save()

        return MigrationReport(
            copiedIncomeSources: copiedIS,
            copiedIncomeSchedules: copiedSch,
            copiedPaySchedules: copiedPS,
            copiedBills: copiedB,
            skippedDuplicates: skipped
        )
    }

    // MARK: - Helpers

    private static func contexts(direction: MigrationDirection, hub: StoreHub) -> (ModelContext, ModelContext) {
        let cloud = ModelContext(hub.iCloudContainer)
        let local = ModelContext(hub.localContainer)
        switch direction {
        case .localToCloud: return (local, cloud)
        case .cloudToLocal: return (cloud, local)
        }
    }
}
