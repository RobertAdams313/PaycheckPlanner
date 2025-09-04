//
//  DataSnapshotBackup.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  DataSnapshotBackup.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/2/25.
//  Purpose: Full JSON backup/restore of SwiftData domain models (Bills, Income, Schedules).
//
//  Notes:
//  - Snapshots include all Bills and Income sources (with their schedules) as DTOs.
//  - Restore supports .merge (idempotent by name/date) and .replace (wipe then reinsert).
//  - This file does not touch AppStorage (handled separately in Settings JSON).
//

import Foundation
import SwiftData

// MARK: - Public API

enum DataSnapshotBackup {

    enum ImportMode {
        case merge   // insert/update matching by stable keys (name + dates), no deletion
        case replace // delete all domain objects first, then insert everything from snapshot
    }

    // MARK: DTOs (Codable, stable)

    struct Snapshot: Codable {
        var bills: [BillDTO]
        var incomes: [IncomeSourceDTO]
    }

    struct BillDTO: Codable, Hashable {
        var name: String
        var amount: Decimal
        var category: String
        var recurrence: String   // rawValue (e.g., "monthly")
        var anchorDueDate: Date  // canonical due anchor
        // Optional future-proof fields:
        var notes: String?
    }

    struct IncomeSourceDTO: Codable, Hashable {
        var name: String
        var defaultAmount: Decimal
        var schedule: IncomeScheduleDTO?
    }

    struct IncomeScheduleDTO: Codable, Hashable {
        var frequency: String      // rawValue (e.g., "biweekly", "semimonthly")
        var anchorDate: Date
        var semimonthlyFirstDay: Int?
        var semimonthlySecondDay: Int?
    }

    // MARK: - Export

    static func exportJSON(context: ModelContext) throws -> URL {
        let current = try captureSnapshot(context: context)
        let data = try encodeSnapshot(current)
        let url = try writeTemp(data: data, suggestedName: "PaycheckPlanner-Data-\(dateStamp()).json")
        return url
    }

    // MARK: - Import

    /// Reads snapshot from URL and applies to SwiftData with the given mode.
    static func `import`(from url: URL, into context: ModelContext, mode: ImportMode) throws {
        let data = try Data(contentsOf: url)
        let snap = try decodeSnapshot(data)
        try restoreSnapshot(snap, into: context, mode: mode)
    }
}

// MARK: - Snapshot capture / restore

private extension DataSnapshotBackup {
    
    static func captureSnapshot(context: ModelContext) throws -> Snapshot {
        // Fetch Bills
        let bills: [Bill] = try context.fetch(FetchDescriptor<Bill>())
        // Fetch Income Sources (and their schedules)
        let incomes: [IncomeSource] = try context.fetch(FetchDescriptor<IncomeSource>())
        
        let billDTOs: [BillDTO] = bills.map { b in
            BillDTO(
                name: b.name,
                amount: b.amount,
                category: b.category,
                recurrence: b.recurrence.rawValue,
                anchorDueDate: b.anchorDueDate,
                notes: nil
            )
        }
        
        let incomeDTOs: [IncomeSourceDTO] = incomes.map { s in
            let schedDTO: IncomeScheduleDTO? = s.schedule.map { sch in
                IncomeScheduleDTO(
                    frequency: sch.frequency.rawValue,
                    anchorDate: sch.anchorDate,
                    semimonthlyFirstDay: sch.frequency == .semimonthly ? sch.semimonthlyFirstDay : nil,
                    semimonthlySecondDay: sch.frequency == .semimonthly ? sch.semimonthlySecondDay : nil
                )
            }
            return IncomeSourceDTO(
                name: s.name,
                defaultAmount: s.defaultAmount,
                schedule: schedDTO
            )
        }
        
        return Snapshot(bills: billDTOs, incomes: incomeDTOs)
    }
    
    static func restoreSnapshot(_ snap: Snapshot, into context: ModelContext, mode: ImportMode) throws {
        switch mode {
        case .replace:
            // wipe all existing domain rows
            try deleteAll(typ: Bill.self, in: context)
            try deleteAll(typ: IncomeSource.self, in: context)
            // reinsert
            try insertAll(from: snap, into: context)
        case .merge:
            // upsert without deleting: matching keys:
            //  - Bill match: name + anchorDueDate
            //  - Income match: name (and schedule.anchorDate if present)
            try mergeAll(from: snap, into: context)
        }
        try context.save()
    }
    
    // MARK: Insert helpers
    
    static func insertAll(from snap: Snapshot, into context: ModelContext) throws {
        for dto in snap.bills {
            let b = Bill()
            b.name = dto.name
            b.amount = dto.amount
            b.category = dto.category
            b.recurrence = BillRecurrence(rawValue: dto.recurrence) ?? .monthly
            b.anchorDueDate = dto.anchorDueDate
            context.insert(b)
        }
        
        for dto in snap.incomes {
            let s = IncomeSource()
            s.name = dto.name
            s.defaultAmount = dto.defaultAmount
            
            if let sch = dto.schedule {
                let sched = IncomeSchedule()
                sched.frequency = PayFrequency(rawValue: sch.frequency) ?? .biweekly
                sched.anchorDate = sch.anchorDate
                if sched.frequency == .semimonthly {
                    sched.semimonthlyFirstDay = sch.semimonthlyFirstDay ?? 1
                    sched.semimonthlySecondDay = sch.semimonthlySecondDay ?? 15
                }
                s.schedule = sched
            } else {
                s.schedule = nil
            }
            context.insert(s)
        }
    }
    
    // MARK: Merge helpers (upsert)
    
    static func mergeAll(from snap: Snapshot, into context: ModelContext) throws {
        // Existing caches
        let existingBills: [Bill] = try context.fetch(FetchDescriptor<Bill>())
        let existingIncomes: [IncomeSource] = try context.fetch(FetchDescriptor<IncomeSource>())
        
        // Index by composite keys
        var billIndex = Diction
    }
}
