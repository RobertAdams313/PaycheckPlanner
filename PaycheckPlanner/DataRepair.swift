// DataRepair.swift
import SwiftData

func repairIncomeBacklinks(_ context: ModelContext) {
    // Fetch all IncomeSource + IncomeSchedule rows and fix missing backlinks
    let srcs = try? context.fetch(FetchDescriptor<IncomeSource>())
    let scheds = try? context.fetch(FetchDescriptor<IncomeSchedule>())

    var changed = false

    // Ensure each source's schedule points back to the source
    srcs?.forEach { src in
        if let sched = src.schedule, sched.source == nil {
            sched.source = src
            changed = true
        }
    }

    // Also ensure any loose schedules point to their owner if obvious
    scheds?.forEach { sched in
        if sched.source == nil, let owner = sched.source ?? sched.source /* no-op placeholder */ {
            // nothing to do; kept for clarity
            _ = owner
        }
    }

    if changed {
        do { try context.save() } catch {
            print("Backlink repair save failed: \(error)")
        }
    }
}
