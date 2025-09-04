//
//  CSVBillRow.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  CSVImporter.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 9/2/25.
//

import Foundation

struct CSVBillRow: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var amount: Decimal
    var category: String
    var dueDate: Date
    var recurrence: String? // once|weekly|biweekly|semimonthly|monthly
    var endDate: Date?
    var notes: String?
}

enum CSVImporter {
    /// Pass a local file URL from `.fileImporter`.
    /// Returns parsed rows; you decide how to upsert into SwiftData.
    static func parseBills(from url: URL) throws -> [CSVBillRow] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return []
        }
        return try parseBills(text: text)
    }

    static func parseBills(text: String) throws -> [CSVBillRow] {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !lines.isEmpty else { return [] }

        // Header (flexible order)
        let headerParts = splitCSVLine(lines[0]).map { $0.lowercased() }
        func idx(_ key: String) -> Int? {
            headerParts.firstIndex(of: key.lowercased())
        }

        let idxName = idx("name")
        let idxAmount = idx("amount")
        let idxCategory = idx("category")
        let idxDue = idx("duedate")
        let idxRec = idx("recurrence")
        let idxEnd = idx("enddate")
        let idxNotes = idx("notes")

        // Require minimal columns
        guard let iName = idxName, let iAmount = idxAmount, let iCategory = idxCategory, let iDue = idxDue else {
            return []
        }

        var result: [CSVBillRow] = []
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        for raw in lines.dropFirst() {
            let cols = splitCSVLine(raw)
            func col(_ i: Int?) -> String? {
                guard let i, cols.indices.contains(i) else { return nil }
                let trimmed = cols[i].trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            guard let name = col(iName),
                  let amountStr = col(iAmount),
                  let category = col(iCategory),
                  let dueStr = col(iDue),
                  let due = df.date(from: dueStr)
            else { continue }

            // Decimal parsing tolerant of commas
            let normalized = amountStr.replacingOccurrences(of: ",", with: "")
            guard let amount = Decimal(string: normalized) else { continue }

            let recurrence = col(idxRec)
            let endDate = col(idxEnd).flatMap { df.date(from: $0) }
            let notes = col(idxNotes)

            result.append(CSVBillRow(
                name: name,
                amount: amount,
                category: category,
                dueDate: due,
                recurrence: recurrence,
                endDate: endDate,
                notes: notes
            ))
        }
        return result
    }

    /// Minimal CSV splitter supporting quoted fields with commas.
    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let ch = iterator.next() {
            if ch == "\"" {
                inQuotes.toggle()
                continue
            }
            if ch == "," && !inQuotes {
                fields.append(current)
                current.removeAll(keepingCapacity: true)
            } else {
                current.append(ch)
            }
        }
        fields.append(current)
        return fields
    }
}
