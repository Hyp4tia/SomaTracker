//
//  NotificationManager.swift
//  SomaTracker
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let storageKey = "notificationsEnabled"
    private let dailyReminderID = "soma.dailyReminder"
    private let endOfDayReminderID = "soma.endOfDayReminder"

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: storageKey)

            // Avoid re-running side effects when the value hasn't actually changed.
            guard oldValue != isEnabled else { return }

            if isEnabled {
                Task { await enableNotifications() }
            } else {
                cancelAllNotifications()
            }
        }
    }

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    // MARK: - Permission

    /// Asks the user for permission to send notifications.
    @discardableResult
    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("[Notifications] Authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedules the morning "Track your day" reminder at the given time.
    func scheduleDailyReminder(hour: Int, minute: Int) {
        scheduleReminder(
            id: dailyReminderID,
            title: "Track your day",
            body: "Don't forget to log your meals and water intake today.",
            hour: hour,
            minute: minute
        )
    }

    /// Schedules the end-of-day "Wrap up your day" reminder at the given time.
    func scheduleEndOfDayReminder(hour: Int, minute: Int) {
        scheduleReminder(
            id: endOfDayReminderID,
            title: "Wrap up your day",
            body: "Log anything you missed before the day ends.",
            hour: hour,
            minute: minute
        )
    }

    /// Schedules a repeating daily notification with the given content and time.
    private func scheduleReminder(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        // Replace any existing reminder before scheduling a new one.
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule reminder \(id): \(error.localizedDescription)")
            }
        }
    }

    /// Cancels all pending and delivered notifications.
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    /// Requests permission and, if granted, schedules the default 11:00 AM and 9:00 PM reminders.
    private func enableNotifications() async {
        let granted = await requestPermission()

        guard granted else {
            // Permission denied — keep state consistent with the system setting.
            isEnabled = false
            return
        }

        scheduleDailyReminder(hour: 11, minute: 0)
        scheduleEndOfDayReminder(hour: 21, minute: 0)
    }
}
