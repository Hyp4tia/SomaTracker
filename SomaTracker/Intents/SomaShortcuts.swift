//
//  SomaShortcuts.swift
//  SomaTracker
//
//  Registers Siri Shortcuts and voice trigger phrases for Apple Intelligence.
//

import AppIntents

struct SomaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMealAppIntent(),
            phrases: [
                "Log meal in \(.applicationName)",
                "Log meal with \(.applicationName)",
                "Track meal in \(.applicationName)",
                "Track meal with \(.applicationName)",
                "Log food in \(.applicationName)",
                "Log food with \(.applicationName)",
                "Quick meal in \(.applicationName)"
            ],
            shortTitle: "Log Meal",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: LogWaterAppIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Log water with \(.applicationName)",
                "Drink water in \(.applicationName)",
                "Add water in \(.applicationName)",
                "Add water to \(.applicationName)",
                "Track water in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
    }
}
