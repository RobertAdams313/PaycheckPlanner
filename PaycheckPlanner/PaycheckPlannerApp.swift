import SwiftUI
import SwiftData

@main
struct PaycheckPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Bill.self, PaySchedule.self, IncomeSource.self, IncomeOverride.self, PaymentStatus.self])
        }
    }
}
