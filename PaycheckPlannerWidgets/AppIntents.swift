import AppIntents
import WidgetKit

// MARK: - Interactive intents (parameter-less for buttons)

struct CyclePrevPaycheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Paycheck"
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let idx = SharedAppGroup.getSnapshotIndex()
        SharedAppGroup.setSnapshotIndex(max(0, idx - 1))
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Previous period")
    }
}

struct CycleNextPaycheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Paycheck"
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let idx = SharedAppGroup.getSnapshotIndex()
        SharedAppGroup.setSnapshotIndex(idx + 1)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Next period")
    }
}

struct MarkBillPaidIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Bill Paid"

    @Parameter(title: "Bill ID") var billID: String
    @Parameter(title: "Paid") var paid: Bool

    init() {}

    // ✅ Assign the wrapped properties directly (not the backing _billID / _paid)
    init(billID: String, paid: Bool) {
        self.billID = billID
        self.paid = paid
    }

    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        SharedAppGroup.setPaid(billID, paid)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Bill updated")
    }
}

// MARK: - Widget configuration intent (for configurable widgets)

// ... your other intents (CyclePrev/Next, MarkBillPaidIntent) unchanged ...

import AppIntents
import WidgetKit

struct PaycheckDisplayConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Paycheck Widget Options"

    // Must be optional for WidgetConfigurationIntent
    @Parameter(title: "Show Mode")
    var mode: Mode?

    init() {}

    // Use the key-path closure form to satisfy the generic requirement
    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$mode
        }
    }

    enum Mode: String, AppEnum, CaseDisplayRepresentable, Sendable {
        case leftoverOnly
        case incomeVsBills
        case billsList

        static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Mode")
        static var caseDisplayRepresentations: [Mode: DisplayRepresentation] = [
            .leftoverOnly: "Leftover only",
            .incomeVsBills: "Income vs Bills",
            .billsList: "Bills list"
        ]
    }
}
