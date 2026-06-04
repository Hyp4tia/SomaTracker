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

    /// Schedules a repeating daily notification at the given time.
    func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Track your day"
        content.body = "Don't forget to log your meals and water intake today."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyReminderID,
            content: content,
            trigger: trigger
        )

        // Replace any existing reminder before scheduling a new one.
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
        center.add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule reminder: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels all pending and delivered notifications.
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Helpers

    /// Requests permission and, if granted, schedules the default 9:00 AM reminder.
    private func enableNotifications() async {
        let granted = await requestPermission()

        guard granted else {
            // Permission denied — keep state consistent with the system setting.
            isEnabled = false
            return
        }

        scheduleDailyReminder(hour: 9, minute: 0)
    }
}
