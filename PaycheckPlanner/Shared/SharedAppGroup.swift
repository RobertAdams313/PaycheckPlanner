//
//  SharedAppGroup.swift
//  PaycheckPlanner
//
//  App <-> Widget bridge: snapshots, index, and paid-bill toggles.
//  Set `identifier` to your App Group for cross-target sharing.
//

import Foundation

// MARK: - App Group bridge

enum SharedAppGroup {
    /// e.g. "group.com.yourcompany.paycheckplanner"
    static let identifier: String? = "group.com.RobAdams.PaycheckPlanner"


    static var defaults: UserDefaults {
        if let id = identifier, let ud = UserDefaults(suiteName: id) { return ud }
        return .standard
    }

    // Storage keys
    private static let snapshotsKey = "pp_snapshots_v1"       // [Snapshot] blob
    private static let snapshotKey  = "pp_snapshot_v1"        // single Snapshot (legacy)
    private static let indexKey     = "pp_snapshot_index_v1"  // Int
    private static let paidBillsKey = "pp_paid_bills_v1"      // [String]

    // MARK: - Snapshot index (for CyclePrev/Next intents)

    static func getSnapshotIndex() -> Int {
        // Default 0 (current/next period)
        let value = defaults.integer(forKey: indexKey)
        return max(0, value)
    }

    static func setSnapshotIndex(_ newValue: Int) {
        defaults.set(max(0, newValue), forKey: indexKey)
    }

    // MARK: - Snapshot save/load

    /// Legacy save (single snapshot). Also updates the snapshots array at index 0.
    static func save(_ snapshot: Snapshot) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let data = try? enc.encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }

        // Keep indexable array in sync (slot 0)
        var list = loadSnapshots()
        if list.isEmpty {
            list = [snapshot]
        } else {
            list[0] = snapshot
        }
        saveSnapshots(list)
    }

    /// Legacy load: returns the snapshot at the current index if available;
    /// falls back to index 0, then to the legacy single snapshot.
    static func load() -> Snapshot? {
        let list = loadSnapshots()
        let idx = getSnapshotIndex()
        if let s = list[safe: idx] { return s }
        if let s0 = list.first { return s0 }

        // Fallback to legacy single
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(Snapshot.self, from: data)
    }

    /// Persist an entire ordered list of snapshots (0 = “current/next”, 1 = “+1”, etc).
    static func saveSnapshots(_ snapshots: [Snapshot]) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let data = try? enc.encode(snapshots) {
            defaults.set(data, forKey: snapshotsKey)
        }
        // Clamp index if it’s now out of range
        let idx = getSnapshotIndex()
        if idx >= snapshots.count { setSnapshotIndex(max(0, snapshots.count - 1)) }
    }

    /// Load the whole snapshot list (may be empty).
    static func loadSnapshots() -> [Snapshot] {
        guard let data = defaults.data(forKey: snapshotsKey) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return (try? dec.decode([Snapshot].self, from: data)) ?? []
    }

    // MARK: - Paid-bill toggles (simple per-pay-period cache)

    /// Builds a stable ID from bill name + due date (yyyy-MM-dd).
    static func billID(_ name: String, _ dueDate: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: dueDate)
        let y = comps.year ?? 0, m = comps.month ?? 0, d = comps.day ?? 0
        let norm = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(norm)|\(y)-\(String(format: "%02d", m))-\(String(format: "%02d", d))"
    }

    static func isPaid(_ id: String) -> Bool {
        currentPaidSet().contains(id)
    }

    static func setPaid(_ id: String, _ paid: Bool) {
        var set = currentPaidSet()
        if paid { set.insert(id) } else { set.remove(id) }
        savePaidSet(set)
    }

    private static func currentPaidSet() -> Set<String> {
        if let arr = defaults.array(forKey: paidBillsKey) as? [String] { return Set(arr) }
        return []
    }

    private static func savePaidSet(_ set: Set<String>) {
        defaults.set(Array(set), forKey: paidBillsKey)
    }
}

// MARK: - Shared models

struct TopBill: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDate: Date
    let category: String?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        dueDate: Date,
        category: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.category = category
    }
}

struct Snapshot: Codable, Hashable {
    let payday: Date
    let incomeTotal: Decimal
    let billsTotal: Decimal
    let carryIn: Decimal
    let remaining: Decimal
    let topBills: [TopBill]
}

// MARK: - Safe subscripting

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
