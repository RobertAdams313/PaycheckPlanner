//  APICatalog.swift
//  PaycheckPlanner
//
//  Single source of truth for app-wide APIs, keys, calls, and integration touchpoints.
//  - Keep this file updated as we add/rename APIs or keys.
//  - Purely additive & non-invasive: compiles standalone, no behavior changes.
//  - Safe to open during code reviews: everything we integrate should be reflected here.
//
//  Updated: 2025-09-04
//
import Foundation
import SwiftUI
import SwiftData

// MARK: - Namespace

/// `PPAPI` groups references to models, services, engines, notifications, storage keys, and UI wiring
/// so that we can reference them consistently across the project.
public enum PPAPI {

    // MARK: Models (SwiftData)
    // These are declarations already present elsewhere in the project.
    // Listed here for discoverability (do not redeclare). Update when fields change.
    public enum Models {
        /// @Model `PaySchedule`
        /// Fields: `frequency: PayFrequency`, `anchorDate: Date`, `semimonthlyFirstDay: Int`, `semimonthlySecondDay: Int`
        public static let paySchedule = "PaySchedule"

        /// @Model `Bill`
        /// Fields (merged): `name: String`, `category: String`, `amount: Decimal`, `anchorDueDate: Date`, `recurrence: BillRecurrence`, ...
        public static let bill = "Bill"

        /// @Model `IncomeSchedule`
        /// Fields (merged): `amount: Decimal`, `anchorDate: Date`, `frequency: PayFrequency`, ...
        public static let incomeSchedule = "IncomeSchedule"

        /// @Model `BillPayment`
        /// Fields: `bill: Bill`, `periodKey: Date` (startOfDay), `markedAt: Date`
        public static let billPayment = "BillPayment"
    }

    // MARK: Storage Bridges & Keys

    /// App ↔︎ Widget bridge layer. Mirrors `SharedAppGroup` implementation.
    public enum AppGroup {
        /// If App Group is configured, this mirrors `SharedAppGroup.identifier` (e.g. "group.com.yourcompany.paycheckplanner").
        /// If not configured, storage falls back to `.standard`.
        public static var identifier: String? { SharedAppGroup.identifier }

        /// Underlying suite for shared storage.
        public static var defaults: UserDefaults { SharedAppGroup.defaults }

        /// Canonical keys used by App ↔︎ Widget bridge.
        public enum Keys {
            /// `[Snapshot]` blob for widget timeline
            public static let snapshots = "pp_snapshots_v1"
            /// Single `Snapshot` (legacy)
            public static let snapshot = "pp_snapshot_v1"
            /// Current index for CyclePrev/Next
            public static let index = "pp_snapshot_index_v1"
            /// Set of paid bill IDs (strings) for lightweight toggles
            public static let paidBills = "pp_paid_bills_v1"
        }

        // Convenience accessors (thin wrappers over SharedAppGroup)
        @inline(__always)
        public static func getSnapshotIndex() -> Int { SharedAppGroup.getSnapshotIndex() }
        @inline(__always)
        public static func setSnapshotIndex(_ i: Int) { SharedAppGroup.setSnapshotIndex(i) }
        @inline(__always)
        public static func getPaidBills() -> [String] { SharedAppGroup.getPaidBills() }
        @inline(__always)
        public static func setPaidBills(_ ids: [String]) { SharedAppGroup.setPaidBills(ids) }
    }

    /// AppStorage keys used throughout Settings & feature flags.
    public enum SettingsKeys {
        // Planning / UI
        public static let planPeriodCount = "planPeriodCount"
        public static let appearance = "appearance"             // "system" | "light" | "dark"
        public static let defaultTab = "defaultTab"              // "plan" | "bills" | "income" | "insights" | "settings"
        public static let billsGrouping = "billsGrouping"        // "dueDate" | "category"

        // Toggles
        public static let hapticsEnabled = "hapticsEnabled"
        public static let carryoverEnabled = "carryoverEnabled"
        public static let notifyBillsEnabled = "notifyBillsEnabled"
        public static let notifyIncomeEnabled = "notifyIncomeEnabled"
    }

    // MARK: Notifications / Bridges

    public enum Notifications {
        /// Fired when a CSV import URL is selected (bridge used by SettingsHostView)
        /// Note: We alias the raw name here to avoid duplicate static definitions.
        public static let csvImportURLSelected = Notification.Name("PPSCSVImportURLSelected")
    }

    // MARK: Services (entry points & responsibilities)

    /// Toggle/query per-bill paid state by normalized period key.
    public enum MarkAsPaidServiceDoc {
        /// Implementation is in `MarkAsPaidService`.
        ///
        /// Key behaviors:
        /// - `key(_ date: Date) -> Date` normalizes to startOfDay for stable lookups.
        /// - `fetchPayment(for:in:context:) -> BillPayment?` returns existing toggle record, if any.
        /// - `togglePaid(for:in:context:)` flips state for the given bill + period.
        public static let typeName = "MarkAsPaidService"
    }

    /// Allocation across periods respecting carryover and due occurrences.
    public enum SafeAllocationEngineDoc {
        /// Implementation is in `SafeAllocationEngine`.
        ///
        /// Referenced helpers:
        /// - `dueOccurrences(...)` to derive bill occurrences within a period window.
        /// - Carryover logic gated by `AppStorage(\n\tcarryoverEnabled)`.
        public static let typeName = "SafeAllocationEngine"
    }

    /// Combines income/bill timelines used by Plan & Insights.
    public enum CombinedPayEventsEngineDoc {
        /// Implementation is in `CombinedPayEventsEngine`.
        ///
        /// Referenced helpers:
        /// - `semiMonthlyBackwards`, `semiMonthlyForwards` for 1st/15th-style schedules.
        public static let typeName = "CombinedPayEventsEngine"
    }

    /// CSV export helpers for per-period breakdowns.
    public enum CSVExporterDoc {
        /// Implementation is in `CSVExporter`.
        ///
        /// Main entry points observed:
        /// - `upcomingCSV(breakdowns:) -> URL`
        /// - `upcomingCSVAsync(...)` (awaits a short delay post-write for safe sharing sheet presentation)
        public static let typeName = "CSVExporter"
    }

    // MARK: Views of Interest (integration points)

    public enum Views {
        /// Editor for income entries. Handles focus-safe currency parsing & save/cancel logic.
        public static let incomeEditor = "IncomeEditorView"

        /// Bills list and editor. Integrates haptics + `MarkAsPaidService.togglePaid(...)`.
        public static let bills = "BillsView / BillEditorView"

        /// Insights host with Swift Charts; queries `IncomeSchedule` & `Bill`.
        public static let insightsHost = "InsightsHostView"

        /// Settings host using AppStorage + snapshot hooks. Launches Data Management screen.
        public static let settingsHost = "SettingsHostView"
        public static let dataManagement = "DataManagementView"
    }

    // MARK: App Intents / Widgets

    public enum IntentsAndWidgets {
        /// Snapshot navigation intents reading/writing `AppGroup.Keys.index`.
        public static let cyclePrevIntent = "CyclePrevIntent"
        public static let cycleNextIntent = "CycleNextIntent"

        /// Toggle intent that mutates `AppGroup.Keys.paidBills`.
        public static let paidBillToggleIntent = "PaidBillToggleIntent"

        /// Widgets consume `[Snapshot]` from `AppGroup.Keys.snapshots` and reflect index changes.
        public static let widgetSnapshots = "Widget Snapshots"
    }

    // MARK: Utility helpers

    public enum CurrencyFormatting {
        /// Format a Decimal using current locale currency rules.
        @inline(__always)
        public static func string(from decimal: Decimal) -> String {
            let n = NSDecimalNumber(decimal: decimal)
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.maximumFractionDigits = 2
            f.minimumFractionDigits = 2
            f.locale = .current
            return f.string(from: n) ?? "$0.00"
        }

        /// Parse a loose currency-like string into Decimal (digits + one dot/comma).
        @inline(__always)
        public static func parse(_ s: String) -> Decimal {
            let cleaned = s
                .replacingOccurrences(of: ",", with: ".")
                .filter { "0123456789.".contains($0) }
            return Decimal(string: cleaned) ?? 0
        }
    }
}

// MARK: - Developer Notes
// 1) When you add a new service, engine, or key:
//    - Reference its canonical name here and briefly document responsibilities.
//    - Add any new UserDefaults/AppStorage keys to `SettingsKeys`.
//    - If you add a new Notification bridge, list it in `Notifications`.
//
// 2) Keep behavior out of this file. It should remain a zero-risk reference & constants hub.
//
// 3) If you rename a model or move a file, update the string identifiers above so search stays easy.
