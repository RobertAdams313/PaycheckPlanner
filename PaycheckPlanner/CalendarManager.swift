import Foundation
import EventKit

@MainActor
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    private let store = EKEventStore()
    @Published private(set) var authorized: Bool = EKEventStore.authorizationStatus(for: .event) == .authorized
    private let calendarTitle = "Paycheck Planner"

    func requestAccess() async -> Bool {
        do { let granted = try await store.requestFullAccessToEvents(); authorized = granted; return granted }
        catch { authorized = false; return false }
    }
    private func ensureCalendar() throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == calendarTitle }) { return existing }
        let source = store.defaultCalendarForNewEvents?.source ?? store.sources.first(where: { $0.sourceType == .local })!
        let cal = EKCalendar(for: .event, eventStore: store); cal.title = calendarTitle; cal.source = source
        try store.saveCalendar(cal, commit: true); return cal
    }
    func addPaydayEvent(date: Date, alertDaysBefore: Int = 1, alertHour: Int = 8, alertMinute: Int = 0) async throws {
        guard authorized else { return }; let calendar = try ensureCalendar()
        let event = EKEvent(eventStore: store); event.title = "Payday"; event.startDate = date; event.endDate = date.addingTimeInterval(3600)
        if let alarmDate = Calendar.current.date(bySettingHour: alertHour, minute: alertMinute, second: 0, of: Calendar.current.date(byAdding: .day, value: -alertDaysBefore, to: date) ?? date) {
            event.alarms = [EKAlarm(absoluteDate: alarmDate)]
        }
        event.calendar = calendar; try store.save(event, span: .thisEvent, commit: true)
    }
    func addBillEvent(name: String, amount: Decimal, dueDate: Date, recurrence: BillRecurrence? = nil, recurrenceEnd: Date? = nil, alertDaysBefore: Int = 1, alertHour: Int = 8, alertMinute: Int = 0) async throws {
        guard authorized else { return }; let calendar = try ensureCalendar()
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.locale = .current
        let event = EKEvent(eventStore: store); event.title = "\(name) due \(nf.string(from: amount as NSDecimalNumber) ?? "")"; event.startDate = dueDate; event.endDate = dueDate.addingTimeInterval(3600)
        if let r = recurrence {
            switch r { case .weekly: event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)]
                      case .monthly: event.recurrenceRules = [EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)]
                      default: break }
        }
        if let endDate = recurrenceEnd { event.recurrenceRules?.first?.recurrenceEnd = EKRecurrenceEnd(end: endDate) }
        if let alarmDate = Calendar.current.date(bySettingHour: alertHour, minute: alertMinute, second: 0, of: Calendar.current.date(byAdding: .day, value: -alertDaysBefore, to: dueDate) ?? dueDate) {
            event.alarms = [EKAlarm(absoluteDate: alarmDate)]
        }
        event.calendar = calendar; try store.save(event, span: .thisEvent, commit: true)
    }
}
