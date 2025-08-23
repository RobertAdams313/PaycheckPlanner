//
//  AppRouter.swift
//  PaycheckPlanner
//

//
//  AppRouter.swift
//  PaycheckPlanner
//

import Foundation

enum MainTab: Hashable {
    case plan, bills, income, insights, settings
}

final class AppRouter: ObservableObject {
    /// Selected tab for the root TabView
    @Published var tab: MainTab = .plan

    /// Global Bill editor sheet toggle (used by Plan empty state, etc.)
    @Published var showAddBillSheet: Bool = false
}
