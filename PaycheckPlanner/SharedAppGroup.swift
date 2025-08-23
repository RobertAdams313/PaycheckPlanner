import Foundation

struct SharedAppGroup {
    static let suite = "group.yourteam.PaycheckPlanner" // <- CHANGE THIS
    static let keyNext = "nextPaycheckSnapshot"
    static let keyNextList = "nextPaycheckSnapshotList"
    static let keyPaid = "paidBillIDs"
    static let keyIndex = "snapshotIndex"

    struct Snapshot: Codable {
        let payday: Date
        let income: Decimal
        let billsTotal: Decimal
        let leftover: Decimal
        let topBills: [TopBill]
        struct TopBill: Codable { let name: String; let amount: Decimal; let dueDate: Date }
    }

    static func save(snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot),
              let ud = UserDefaults(suiteName: suite) else { return }
        ud.set(data, forKey: keyNext)
    }
    static func load() -> Snapshot? {
        guard let ud = UserDefaults(suiteName: suite),
              let data = ud.data(forKey: keyNext),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        return snap
    }
    static func saveList(snapshots: [Snapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots),
              let ud = UserDefaults(suiteName: suite) else { return }
        ud.set(data, forKey: keyNextList)
    }
    static func loadList() -> [Snapshot] {
        guard let ud = UserDefaults(suiteName: suite),
              let data = ud.data(forKey: keyNextList),
              let snaps = try? JSONDecoder().decode([Snapshot].self, from: data) else { return [] }
        return snaps
    }
    static func billID(_ name: String, _ due: Date) -> String {
        let fmt = ISO8601DateFormatter()
        return name + "::" + fmt.string(from: due)
    }
    static func setPaid(_ id: String, _ paid: Bool) {
        guard let ud = UserDefaults(suiteName: suite) else { return }
        var set = Set((ud.array(forKey: keyPaid) as? [String]) ?? [])
        if paid { set.insert(id) } else { set.remove(id) }
        ud.set(Array(set), forKey: keyPaid)
    }
    static func isPaid(_ id: String) -> Bool {
        guard let ud = UserDefaults(suiteName: suite) else { return false }
        let arr = (ud.array(forKey: keyPaid) as? [String]) ?? []
        return Set(arr).contains(id)
    }
    static func setSnapshotIndex(_ idx: Int) {
        UserDefaults(suiteName: suite)?.set(idx, forKey: keyIndex)
    }
    static func getSnapshotIndex() -> Int {
        UserDefaults(suiteName: suite)?.integer(forKey: keyIndex) ?? 0
    }
}
