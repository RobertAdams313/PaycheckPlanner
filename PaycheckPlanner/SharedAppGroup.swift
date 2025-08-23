//
//  SharedAppGroup.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//


import Foundation

enum SharedAppGroup {
    // 🔧 Set this to your actual App Group ID
    static let suite = "group.yourteam.PaycheckPlanner"

    // Use group defaults if available; otherwise fall back to standard so we never crash.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: suite) ?? .standard
    }

    struct Snapshot: Codable {
        struct TopBill: Codable {
            let name: String
            let amount: Decimal
            let dueDate: Date
        }
        let payday: Date
        let income: Decimal
        let billsTotal: Decimal
        let leftover: Decimal
        let topBills: [TopBill]
    }

    static func billID(_ name: String, _ due: Date) -> String {
        let iso = ISO8601DateFormatter()
        return "\(name)|\(iso.string(from: due))"
    }

    static func isPaid(_ id: String) -> Bool {
        defaults.bool(forKey: "paid.\(id)")
    }
    static func setPaid(_ id: String, _ paid: Bool) {
        defaults.set(paid, forKey: "paid.\(id)")
    }

    static func getSnapshotIndex() -> Int {
        max(0, defaults.integer(forKey: "snapshotIndex"))
    }
    static func setSnapshotIndex(_ idx: Int) {
        defaults.set(max(0, idx), forKey: "snapshotIndex")
    }

    static func load() -> Snapshot? {
        guard let data = defaults.data(forKey: "snapshot") else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
    static func save(_ snap: Snapshot) {
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: "snapshot")
        }
    }

    static func containerURL() -> URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite)
        ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
