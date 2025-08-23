import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var schedule: PaySchedule
    @AppStorage("defaultUpcomingCount") private var defaultUpcomingCount: Int = 6
    @AppStorage("autoPushToCalendar") private var autoPushToCalendar: Bool = false
    @AppStorage("alertDaysBefore") private var alertDaysBefore: Int = 1
    @AppStorage("alertHour") private var alertHour: Int = 8
    @AppStorage("alertMinute") private var alertMinute: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("Pay Schedule") {
                    Picker("Frequency", selection: $schedule.frequency) { ForEach(PayFrequency.allCases) { Text($0.displayName).tag($0) } }
                    DatePicker("Anchor payday", selection: $schedule.anchorDate, displayedComponents: [.date])
                    if schedule.frequency == .semimonthly {
                        Stepper("First day: \(schedule.semimonthlyFirstDay)", value: $schedule.semimonthlyFirstDay, in: 1...28)
                        Stepper("Second day: \(schedule.semimonthlySecondDay)", value: $schedule.semimonthlySecondDay, in: 1...28)
                    }
                }
                Section("Base Income (optional)") {
                    TextField("Per-paycheck base amount", value: $schedule.paycheckAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD")).keyboardType(.decimalPad)
                    NavigationLink("Manage income sources") { IncomeSourcesView() }
                }
                Section("Calendar") {
                    Toggle("Automatically add future paydays to Calendar", isOn: $autoPushToCalendar)
                    Stepper("Alert days before: \(alertDaysBefore)", value: $alertDaysBefore, in: 0...7)
                    HStack {
                        Stepper("Hour: \(alertHour)", value: $alertHour, in: 0...23)
                        Stepper("Minute: \(alertMinute)", value: $alertMinute, in: 0...55, step: 5)
                    }
                }
                Section("Display") {
                    Stepper("Future paychecks: \(defaultUpcomingCount)", value: $defaultUpcomingCount, in: 3...24, step: 3)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
