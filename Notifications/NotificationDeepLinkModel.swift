//
//  NotificationDeepLink.swift
//  PaycheckPlanner
//
//  Created by Rob on 9/2/25.
//

import SwiftUI
import SwiftData

@MainActor
final class NotificationDeepLinkModel: ObservableObject, Identifiable {
    @Published var targetBreakdown: CombinedBreakdown? = nil
    let id = UUID()
}

struct NotificationDeepLinkPresenter: ViewModifier {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @StateObject private var model = NotificationDeepLinkModel()

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openPaycheckDetail)) { output in
                guard let paydayStr = output.userInfo?["payday"] as? String else { return }
                let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
                guard let payday = df.date(from: paydayStr) else { return }

                Task { @MainActor in
                    // Switch to Plan tab
                    router.tab = .plan

                    // Build data to find matching period
                    let schedules: [IncomeSchedule] = (try? context.fetch(FetchDescriptor<IncomeSchedule>())) ?? []
                    let bills: [Bill]               = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
                    let periods = CombinedPayEventsEngine.combinedPeriods(schedules: schedules, count: 12)
                    let breakdowns = SafeAllocationEngine.allocate(bills: bills, into: periods)

                    if let match = breakdowns.first(where: { Calendar.current.isDate($0.period.payday, inSameDayAs: payday) }) {
                        model.targetBreakdown = match
                    }
                }
            }
            .sheet(item: $model.targetBreakdown) { b in
                PaycheckDetailView(breakdown: b)
            }
    }
}

extension View {
    func withNotificationDeepLinking() -> some View {
        modifier(NotificationDeepLinkPresenter())
    }
}
