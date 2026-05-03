//
//  NotificationManager.swift
//  chinese-poetry
//
//  Created by 辛保健 on 2026/5/3.
//

import Foundation
import UserNotifications

struct NotificationManager {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleDailyReminder(at hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "古诗词复习提醒"
        content.body = "今天有古诗词需要复习哦，快来背诵吧！"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_review_reminder", content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
