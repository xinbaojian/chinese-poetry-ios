import SwiftUI

struct ReminderSettingsView: View {
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 9
    @AppStorage("reminderMinute") private var reminderMinute = 0

    private var reminderDate: Date {
        get {
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection {
                    Toggle("开启每日提醒", isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    _ = try? await NotificationManager.requestAuthorization()
                                    NotificationManager.scheduleDailyReminder(
                                        at: reminderHour, minute: reminderMinute
                                    )
                                }
                            } else {
                                NotificationManager.cancelDailyReminder()
                            }
                        }

                    if reminderEnabled {
                        Divider()
                        DatePicker("提醒时间", selection: Binding(
                            get: { reminderDate },
                            set: { newDate in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                reminderHour = components.hour ?? 9
                                reminderMinute = components.minute ?? 0
                                if reminderEnabled {
                                    NotificationManager.scheduleDailyReminder(
                                        at: reminderHour, minute: reminderMinute
                                    )
                                }
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("复习提醒")
        .navigationBarTitleDisplayMode(.inline)
    }
}
