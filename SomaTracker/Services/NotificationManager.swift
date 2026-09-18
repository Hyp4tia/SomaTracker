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
    private let dailyReminderTimeKey = "dailyReminderTime"
    private let eveningReminderTimeKey = "eveningReminderTime"
    private let dailyReminderID = "soma.dailyReminder"
    private let endOfDayReminderID = "soma.endOfDayReminder"

    /// Set when the user has notification permission turned off in system settings, so the
    /// UI can offer a route to Settings instead of silently snapping the toggle back.
    @Published var permissionDenied = false

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

    @Published var dailyReminderTime: Date {
        didSet {
            UserDefaults.standard.set(dailyReminderTime, forKey: dailyReminderTimeKey)
            if isEnabled {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
                scheduleDailyReminder(hour: comps.hour ?? 11, minute: comps.minute ?? 0)
            }
        }
    }

    @Published var eveningReminderTime: Date {
        didSet {
            UserDefaults.standard.set(eveningReminderTime, forKey: eveningReminderTimeKey)
            if isEnabled {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: eveningReminderTime)
                scheduleEndOfDayReminder(hour: comps.hour ?? 21, minute: comps.minute ?? 0)
            }
        }
    }

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: storageKey)

        let calendar = Calendar.current
        let now = Date()

        if let savedDaily = UserDefaults.standard.object(forKey: dailyReminderTimeKey) as? Date {
            self.dailyReminderTime = savedDaily
        } else {
            self.dailyReminderTime = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: now) ?? now
        }

        if let savedEvening = UserDefaults.standard.object(forKey: eveningReminderTimeKey) as? Date {
            self.eveningReminderTime = savedEvening
        } else {
            self.eveningReminderTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now
        }
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

    /// Re-reads the system permission so the toggle cannot lie. iOS Settings can revoke
    /// notifications without the app being told, which used to leave a green switch promising
    /// reminders that could never arrive. Only flags the alert when the toggle claimed to be on.
    func refreshPermissionState() async {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            if isEnabled {
                isEnabled = false // didSet clears the pending reminders
                permissionDenied = true
            }
        case .authorized, .provisional, .ephemeral:
            permissionDenied = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    /// Post-onboarding opt-in: asks for permission, then turns the toggle on so the saved
    /// reminder times are scheduled. Returns whether reminders are actually live.
    func enableRemindersFromPrompt() async -> Bool {
        guard await requestPermission() else {
            permissionDenied = true
            return false
        }

        permissionDenied = false
        if !isEnabled { isEnabled = true }
        return true
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

    /// Requests permission and, if granted, schedules the saved daily and evening reminders.
    private func enableNotifications() async {
        let granted = await requestPermission()

        guard granted else {
            // Permission denied — keep state consistent with the system setting and let the
            // UI point the user at Settings instead of leaving a dead toggle behind.
            permissionDenied = true
            isEnabled = false
            return
        }

        permissionDenied = false
        let calendar = Calendar.current
        let dailyComps = calendar.dateComponents([.hour, .minute], from: dailyReminderTime)
        let eveningComps = calendar.dateComponents([.hour, .minute], from: eveningReminderTime)

        scheduleDailyReminder(hour: dailyComps.hour ?? 11, minute: dailyComps.minute ?? 0)
        scheduleEndOfDayReminder(hour: eveningComps.hour ?? 21, minute: eveningComps.minute ?? 0)
    }
}
