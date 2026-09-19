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
            intent: LogWaterAppIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Log water with \(.applicationName)",
                "Drink water in \(.applicationName)",
                "Add water in \(.applicationName)",
                "Add water to \(.applicationName)",
                "Track water in \(.applicationName)",
                "Log hydration in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: LogMealAppIntent(),
            phrases: [
                "Log in \(.applicationName)",
                "Log with \(.applicationName)",
                "Log meal in \(.applicationName)",
                "Log meal with \(.applicationName)",
                "Track meal in \(.applicationName)",
                "Track meal with \(.applicationName)",
                "Log food in \(.applicationName)",
                "Log food with \(.applicationName)",
                "Track food in \(.applicationName)",
                "Quick meal in \(.applicationName)"
            ],
            shortTitle: "Log Meal",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: SnapMealPhotoAppIntent(),
            phrases: [
                "Snap meal photo in \(.applicationName)",
                "Take meal photo with \(.applicationName)",
                "Scan food in \(.applicationName)",
                "Scan food with \(.applicationName)",
                "Camera in \(.applicationName)"
            ],
            shortTitle: "Snap Meal Photo",
            systemImageName: "camera.fill"
        )

        AppShortcut(
            intent: GetDailyNutritionIntent(),
            phrases: [
                "Check \(.applicationName)",
                "Check \(.applicationName) for today",
                "How much \(\.$metric) do I have left in \(.applicationName)",
                "How many calories left in \(.applicationName)",
                "How much water have I had in \(.applicationName)",
                "How many steps in \(.applicationName)"
            ],
            shortTitle: "Check Today",
            systemImageName: "chart.pie.fill"
        )

        AppShortcut(
            intent: GetStreakStatusIntent(),
            phrases: [
                "What's my streak in \(.applicationName)",
                "Check my streak in \(.applicationName)",
                "How is my streak in \(.applicationName)"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame.fill"
        )

        AppShortcut(
            intent: RecordVoiceMealAppIntent(),
            phrases: [
                "Record voice meal in \(.applicationName)",
                "Voice meal in \(.applicationName)",
                "Voice meal with \(.applicationName)",
                "Speak meal to \(.applicationName)",
                "Voice memo in \(.applicationName)"
            ],
            shortTitle: "Record Voice Meal",
            systemImageName: "mic.fill"
        )
    }
}
