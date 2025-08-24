import SwiftUI

enum MainTab: Hashable {
    case plan
    case bills
    case income
    case insights
    case settings
}

final class AppRouter: ObservableObject {
    @Published var tab: MainTab = .plan

    /// When set to true, the Bills tab should present the Add Bill sheet.
    @Published var showAddBillSheet: Bool = false
}
