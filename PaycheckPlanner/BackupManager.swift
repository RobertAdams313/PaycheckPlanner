//
//  BackupManager.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Backup/Restore for SwiftData models (JSON, versioned).
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - File Type

extension UTType {
    /// A custom backup type that still serializes as JSON.
    static let paycheckPlannerBackup = UTType(exportedAs: "com.robadams.paycheckplanner.backup",
                                              conformingTo: .json)
}

// MARK: - DTOs (Stable, Codable representations)

/// Bump this if you change the payload shape.
private let kBackupVersion = 1

struct AppBackup: Codable {
    let version: Int
    let createdAt: Date
    let bills: [BillDTO]
    let incomeSchedules: [IncomeScheduleDTO]
    let incomeSources: [IncomeSourceDTO]
}

// Mirror of Bill model (keep fields aligned with your @Model)
struct BillDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Decimal
    var anchorDueDate: Date
    var recurrence: BillRecurrence
    var category: String
    var endDate: Date?
}

// Mirror of IncomeSchedule model (align with your @Model)
struct IncomeScheduleDTO: Codable, Identifiable {
    var id: UUID
    var name: String?           // if your model has it; harmless if nil
    var frequency: PayFrequency
    var anchorDate: Date
    var semimonthlyFirstDay: Int
    var amount: Decimal?        // if amount is on schedule; harmless if nil
}

// Mirror of IncomeSource model (align with your @Model, if present)
struct IncomeSourceDTO: Codable, Identifiable {
    var id: UUID
    var name: String
    var amount: Decimal
}

// MARK: - Backup Manager

enum BackupManager {
    // MARK: Export

    /// Builds a single JSON file for all data and writes it to a temporary location.
    /// You pass the resulting URL to a `.fileExporter`.
    static func makeBackupFile(context: ModelContext) throws -> URL {
        let payload = try buildPayload(context: context)
        let (data, filename) = try encode(payload: payload)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Import

    /// Reads an on-disk backup and restores into SwiftData.
    /// - Parameters:
    ///   - url: URL from `.fileImporter`
    ///   - strategy:
    ///       `.append` – keep existing data, add/merge by ID
    ///       `.replaceAll` – wipe existing objects of the same types, then import
    static func restore(from url: URL,
                        into context: ModelContext,
                        strategy: RestoreStrategy = .append) throws {
        let data = try Data(contentsOf: url)
        let payload = try decode(data: data)

        try context.transaction {
            if strategy == .replaceAll {
                try wipeAll(context: context)
            }
            try upsert(payload: payload, context: context)
        }
    }

    enum RestoreStrategy {
        case append
        case replaceAll
    }
}

// MARK: - Build/Encode/Decode

private extension BackupManager {
    static func buildPayload(context: ModelContext) throws -> AppBackup {
        // Fetch everything we know how to back up.
        let bills = try context.fetch(FetchDescriptor<Bill>())
        let schedules = try context.fetch(FetchDescriptor<IncomeSchedule>())
        // `IncomeSource` may be separate in your schema. If not, we still remain safe.
        let sources = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []

        let billDTOs = bills.map { b in
            BillDTO(
                id: (b as AnyObject).value(forKey: "id") as? UUID ?? UUID(),
                name: (b as AnyObject).value(forKey: "name") as? String ?? "",
                amount: (b as AnyObject).value(forKey: "amount") as? Decimal ?? 0,
                anchorDueDate: (b as AnyObject).value(forKey: "anchorDueDate") as? Date ?? .now,
                recurrence: (b as AnyObject).value(forKey: "recurrence") as? BillRecurrence ?? .monthly,
                category: (b as AnyObject).value(forKey: "category") as? String ?? "",
                endDate: (b as AnyObject).value(forKey: "endDate") as? Date
            )
        }

        let scheduleDTOs = schedules.map { s in
            IncomeScheduleDTO(
                id: (s as AnyObject).value(forKey: "id") as? UUID ?? UUID(),
                name: (s as AnyObject).value(forKey: "name") as? String,
                frequency: (s as AnyObject).value(forKey: "frequency") as? PayFrequency ?? .biweekly,
                anchorDate: (s as AnyObject).value(forKey: "anchorDate") as? Date ?? .now,
                semimonthlyFirstDay: (s as AnyObject).value(forKey: "semimonthlyFirstDay") as? Int ?? 1,
                amount: (s as AnyObject).value(forKey: "amount") as? Decimal
            )
        }

        let sourceDTOs = sources.map { s in
            IncomeSourceDTO(
                id: (s as AnyObject).value(forKey: "id") as? UUID ?? UUID(),
                name: (s as AnyObject).value(forKey: "name") as? String ?? "",
                amount: (s as AnyObject).value(forKey: "amount") as? Decimal ?? 0
            )
        }

        return AppBackup(
            version: kBackupVersion,
            createdAt: Date(),
            bills: billDTOs,
            incomeSchedules: scheduleDTOs,
            incomeSources: sourceDTOs
        )
    }

    static func encode(payload: AppBackup) throws -> (Data, String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        // Decimal support
        encoder.nonConformingFloatEncodingStrategy = .throw

        let data = try encoder.encode(payload)

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let ts = df.string(from: payload.createdAt).replacingOccurrences(of: ":", with: "-")

        let filename = "PaycheckPlanner-\(ts).paycheckplanner-backup.json"
        return (data, filename)
    }

    static func decode(data: Data) throws -> AppBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppBackup.self, from: data)
    }
}

// MARK: - Restore Helpers

private extension BackupManager {
    static func wipeAll(context: ModelContext) throws {
        // Delete Bills
        let bills = try context.fetch(FetchDescriptor<Bill>())
        bills.forEach { context.delete($0) }

        // Delete IncomeSchedules
        let schedules = try context.fetch(FetchDescriptor<IncomeSchedule>())
        schedules.forEach { context.delete($0) }

        // Delete IncomeSources (if present)
        if let sources = try? context.fetch(FetchDescriptor<IncomeSource>()) {
            sources.forEach { context.delete($0) }
        }
    }

    static func upsert(payload: AppBackup, context: ModelContext) throws {
        // Bills
        var billIndex: [UUID: Bill] = [:]
        for existing in try context.fetch(FetchDescriptor<Bill>()) {
            if let id = (existing as AnyObject).value(forKey: "id") as? UUID {
                billIndex[id] = existing
            }
        }
        for dto in payload.bills {
            if let target = billIndex[dto.id] {
                // Update
                (target as AnyObject).setValue(dto.name, forKey: "name")
                (target as AnyObject).setValue(dto.amount, forKey: "amount")
                (target as AnyObject).setValue(dto.anchorDueDate, forKey: "anchorDueDate")
                (target as AnyObject).setValue(dto.recurrence, forKey: "recurrence")
                (target as AnyObject).setValue(dto.category, forKey: "category")
                (target as AnyObject).setValue(dto.endDate, forKey: "endDate")
            } else {
                // Insert (uses memberwise init via reflection-safe assignment)
                let newBill = Bill()
                (newBill as AnyObject).setValue(dto.id, forKey: "id")
                (newBill as AnyObject).setValue(dto.name, forKey: "name")
                (newBill as AnyObject).setValue(dto.amount, forKey: "amount")
                (newBill as AnyObject).setValue(dto.anchorDueDate, forKey: "anchorDueDate")
                (newBill as AnyObject).setValue(dto.recurrence, forKey: "recurrence")
                (newBill as AnyObject).setValue(dto.category, forKey: "category")
                (newBill as AnyObject).setValue(dto.endDate, forKey: "endDate")
                context.insert(newBill)
            }
        }

        // IncomeSchedules
        var scheduleIndex: [UUID: IncomeSchedule] = [:]
        for existing in try context.fetch(FetchDescriptor<IncomeSchedule>()) {
            if let id = (existing as AnyObject).value(forKey: "id") as? UUID {
                scheduleIndex[id] = existing
            }
        }
        for dto in payload.incomeSchedules {
            if let target = scheduleIndex[dto.id] {
                (target as AnyObject).setValue(dto.name, forKey: "name")
                (target as AnyObject).setValue(dto.frequency, forKey: "frequency")
                (target as AnyObject).setValue(dto.anchorDate, forKey: "anchorDate")
                (target as AnyObject).setValue(dto.semimonthlyFirstDay, forKey: "semimonthlyFirstDay")
                (target as AnyObject).setValue(dto.amount, forKey: "amount")
            } else {
                let s = IncomeSchedule()
                (s as AnyObject).setValue(dto.id, forKey: "id")
                (s as AnyObject).setValue(dto.name, forKey: "name")
                (s as AnyObject).setValue(dto.frequency, forKey: "frequency")
                (s as AnyObject).setValue(dto.anchorDate, forKey: "anchorDate")
                (s as AnyObject).setValue(dto.semimonthlyFirstDay, forKey: "semimonthlyFirstDay")
                (s as AnyObject).setValue(dto.amount, forKey: "amount")
                context.insert(s)
            }
        }

        // IncomeSources (if present in your schema)
        if let _ = try? context.fetch(FetchDescriptor<IncomeSource>()) {
            var sourceIndex: [UUID: IncomeSource] = [:]
            for existing in (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? [] {
                if let id = (existing as AnyObject).value(forKey: "id") as? UUID {
                    sourceIndex[id] = existing
                }
            }
            for dto in payload.incomeSources {
                if let target = sourceIndex[dto.id] {
                    (target as AnyObject).setValue(dto.name, forKey: "name")
                    (target as AnyObject).setValue(dto.amount, forKey: "amount")
                } else {
                    let s = IncomeSource()
                    (s as AnyObject).setValue(dto.id, forKey: "id")
                    (s as AnyObject).setValue(dto.name, forKey: "name")
                    (s as AnyObject).setValue(dto.amount, forKey: "amount")
                    context.insert(s)
                }
            }
        }
    }
}
