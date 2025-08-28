import AppIntents
import WidgetKit

// Tap actions
struct CyclePrevPaycheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Paycheck"
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let idx = SharedAppGroup.getSnapshotIndex()
        SharedAppGroup.setSnapshotIndex(max(0, idx - 1))
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Showing previous period")
    }
}

struct CycleNextPaycheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Paycheck"
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let idx = SharedAppGroup.getSnapshotIndex()
        SharedAppGroup.setSnapshotIndex(idx + 1)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Showing next period")
    }
}

struct MarkBillPaidIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Bill Paid"

    @Parameter(title: "Bill ID")
    var billID: String

    init() {}

    // Explicit initializer so Button(intent:) can pass IntentParameter<String>
    init(billID: IntentParameter<String>) {
        self._billID = billID
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle paid for \(\.$billID)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = billID
        let currentlyPaid = SharedAppGroup.isPaid(id)
        SharedAppGroup.setPaid(id, !currentlyPaid)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: currentlyPaid ? "Marked unpaid" : "Marked paid")
    }
}

// Widget configuration intent
enum PaycheckDisplayMode: String, AppEnum {
    static var typeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("Display Mode"))

    case leftoverOnly
    case billsAndLeftover

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .leftoverOnly:    DisplayRepresentation(title: LocalizedStringResource("Leftover Only")),
        .billsAndLeftover: DisplayRepresentation(title: LocalizedStringResource("Bills + Leftover"))
    ]

    
}

struct PaycheckDisplayConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Paycheck Widget Options"
    static var description = IntentDescription("Configure what the widget shows.")

    @Parameter(title: "Display")
    var mode: PaycheckDisplayMode?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$mode)")
    }
}
