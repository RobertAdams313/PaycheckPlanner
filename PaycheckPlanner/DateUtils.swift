//
//  PayDateUtils.swift
//  PaycheckPlanner
//
//  Created by Robert Adams on 8/23/25.
//  Copyright © 2025 Rob Adams. All rights reserved.
//


//
//  DateUtils.swift
//  PaycheckPlanner
//

import Foundation

/// Safe payday utilities that avoid force-unwraps and handle empty arrays gracefully.
struct PayDateUtils {
    
    /// Returns the previous payday for a schedule.
    static func previousPayday(schedule: PaySchedule, paydays: [Date]) -> Date {
        let cal = Calendar.current
        let base = paydays.first ?? schedule.anchorDate
        
        switch schedule.frequency {
        case .once:
            // One-time income: fake a prior boundary 14 days earlier so period math has a start
            return cal.date(byAdding: .day, value: -14, to: base) ?? base
            
        case .weekly:
            return cal.date(byAdding: .day, value: -7, to: base) ?? base
            
        case .biweekly:
            return cal.date(byAdding: .day, value: -14, to: base) ?? base
            
        case .semimonthly:
            return previousSemimonthly(base: base, schedule: schedule, calendar: cal)
            
        case .monthly:
            return cal.date(byAdding: .month, value: -1, to: base) ?? base
        }
    }
    
    /// Returns the future paydays for a schedule, starting from its anchor date.
    static func futurePaydays(schedule: PaySchedule, count: Int) -> [Date] {
        var results: [Date] = []
        let cal = Calendar.current
        var current = cal.startOfDay(for: schedule.anchorDate)
        let n = max(1, count)
        
        switch schedule.frequency {
        case .once:
            // Emit a single payday (the anchor date)
            return [current]
            
        case .weekly:
            for _ in 0..<n {
                results.append(current)
                current = cal.date(byAdding: .day, value: 7, to: current) ?? current
            }
            return results
            
        case .biweekly:
            for _ in 0..<n {
                results.append(current)
                current = cal.date(byAdding: .day, value: 14, to: current) ?? current
            }
            return results
            
        case .semimonthly:
            return futureSemimonthlyPaydays(base: current, schedule: schedule, calendar: cal, count: n)
            
        case .monthly:
            for _ in 0..<n {
                results.append(current)
                current = cal.date(byAdding: .month, value: 1, to: current) ?? current
            }
            return results
        }
    }
    
    // MARK: - Semimonthly helpers
    
    private static func previousSemimonthly(base: Date, schedule: PaySchedule, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        let d1 = schedule.semimonthlyFirstDay
        let d2 = schedule.semimonthlySecondDay
        let days = [d1, d2].sorted()
        
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return base
        }
        
        var candidate: Date? = nil
        for dd in days.reversed() {
            if day > dd {
                comps.day = dd
                candidate = calendar.date(from: comps)
                break
            }
        }
        if candidate == nil {
            // go back one month, take the latest of d1/d2
            comps.month = month - 1
            comps.day = days.last
            candidate = calendar.date(from: comps)
        }
        return candidate ?? base
    }
    
    private static func futureSemimonthlyPaydays(base: Date, schedule: PaySchedule, calendar: Calendar, count: Int) -> [Date] {
        var out: [Date] = []
        var comps = calendar.dateComponents([.year, .month], from: base)
        let days = [schedule.semimonthlyFirstDay, schedule.semimonthlySecondDay].sorted()
        
        while out.count < count {
            guard let y = comps.year, let m = comps.month else { break }
            for dd in days {
                var c = DateComponents()
                c.year = y; c.month = m; c.day = dd
                if let d = calendar.date(from: c), d >= base {
                    out.append(calendar.startOfDay(for: d))
                    if out.count >= count { break }
                }
            }
            comps.month = m + 1
        }
        return out
    }
}
