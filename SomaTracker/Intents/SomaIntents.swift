//
//  SomaIntents.swift
//  SomaTracker
//
//  Audited App Intents providing seamless Apple Intelligence & Siri integration
//  for natural commands like "log 100 water", "log 500 calories", "log a chicken salad".
//

import AppIntents
import SwiftData
import Foundation

struct LogWaterAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water in Soma"
    static var description = IntentDescription("Log water intake into Soma (e.g. 'log 50 water' or 'log 500 ml water').")

    @Parameter(
        title: "Amount",
        description: "The amount of water in milliliters (e.g. 50, 100, 250, 500)",
        requestValueDialog: IntentDialog("How many milliliters of water did you drink?")
    )
    var amount: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) ml of water")
    }

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        guard SubscriptionManager.shared.canUseAIFeatures else {
            return .result(
                value: "Subscription Required",
                dialog: "Siri integration requires Soma Pro or remaining free AI scans. Please open Soma to upgrade."
            )
        }

        // Shared container: intents run inside the app process, so a second container
        // over the same store would be a needless second writer on one SQLite file.
        let context = SomaPersistence.shared.mainContext
        let todayLog = DailyLog.fetchOrCreateToday(context: context)
        let aiEntryId = UUID()

        // Siri takes free text, so keep the amount inside a physically plausible bottle.
        let targetML = min(max(1, amount), 2_000)
        let entry = WaterEntry(amount: targetML, timestamp: .now, label: "Soma AI", aiMealEntryId: aiEntryId)
        todayLog.waterEntries.append(entry)

        let aiEntry = AIMealEntry(
            id: aiEntryId,
            title: "Hydration (\(targetML) ml)",
            location: "Logged with Soma AI",
            storyText: "Voice logged via Siri: \(targetML) ml water.",
            calories: 0,
            proteinG: 0,
            carbsG: 0,
            fatG: 0,
            breakdownNotes: "Logged \(targetML) ml of water via Siri."
        )
        aiEntry.dailyLog = todayLog
        context.insert(aiEntry)

        SubscriptionManager.shared.consumeFreeScanIfFreeUser()

        do {
            try context.save()
        } catch {
            return .result(
                value: "Not Logged",
                dialog: "Soma couldn't save that. Please try again."
            )
        }
        await HealthSyncService.shared.syncDay(todayLog)

        return .result(
            value: "Logged \(targetML) ml",
            dialog: "Added \(targetML) ml of water to your daily hydration in Soma."
        )
    }
}

struct LogMealAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Food & Nutrition in Soma"
    static var description = IntentDescription("Log any meal, calories, or protein using natural speech (e.g. 'log a chicken salad', 'log 500 calories', 'log 40 protein').")

    @Parameter(
        title: "Food or Nutrition Description",
        description: "Description of what you ate or drank",
        requestValueDialog: IntentDialog("What did you eat or drink?")
    )
    var item: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$item)")
    }

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        guard SubscriptionManager.shared.canUseAIFeatures else {
            return .result(
                value: "Subscription Required",
                dialog: "Soma AI meal logging requires Soma Pro or remaining free AI scans. Please open Soma to upgrade."
            )
        }

        // Shared container: intents run inside the app process, so a second container
        // over the same store would be a needless second writer on one SQLite file.
        let context = SomaPersistence.shared.mainContext
        let todayLog = DailyLog.fetchOrCreateToday(context: context)
        let aiEntryId = UUID()

        // 1. First check if user is logging water: "log 100 water", "50 water", "سجل ١٠٠ مية"
        let waterCheck = FoodNutritionDatabase.shared.parseInput(item)
        if waterCheck.isWater {
            let waterEntry = WaterEntry(amount: waterCheck.waterML, timestamp: .now, label: "Soma AI", aiMealEntryId: aiEntryId)
            todayLog.waterEntries.append(waterEntry)

            let aiEntry = AIMealEntry(
                id: aiEntryId,
                title: "Hydration (\(waterCheck.waterML) ml)",
                location: "Logged with Soma AI",
                storyText: "Captured via Siri: \"\(item)\".",
                calories: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                breakdownNotes: waterCheck.summary
            )
            aiEntry.dailyLog = todayLog
            context.insert(aiEntry)

            SubscriptionManager.shared.consumeFreeScanIfFreeUser()

            do {
                try context.save()
            } catch {
                return .result(
                    value: "Not Logged",
                    dialog: "Soma couldn't save that. Please try again."
                )
            }
            await HealthSyncService.shared.syncDay(todayLog)

            return .result(
                value: "Logged \(waterCheck.waterML) ml",
                dialog: "Added \(waterCheck.waterML) ml of water to your daily hydration in Soma."
            )
        }

        // 2. Parse meal using AIRouter (Gemini Flash through the proxy when online, on-device engine otherwise)
        let analysis = await AIRouter.shared.processMultimodalMeal(
            notes: item,
            photos: [],
            audioURL: nil
        )

        // 3. Standard Food Entry in DailyLog
        let foodEntry = FoodEntry(
            name: analysis.title,
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            mealType: "Soma AI",
            timestamp: .now,
            aiMealEntryId: aiEntryId
        )
        todayLog.foodEntries.append(foodEntry)

        // 4. Also create an AIMealEntry so it surfaces in the AI Journal
        let aiEntry = AIMealEntry(
            id: aiEntryId,
            title: analysis.title,
            location: "Logged with Soma AI",
            storyText: "Quickly captured via Siri: \"\(item)\".",
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            breakdownNotes: analysis.storyNarrative
        )
        aiEntry.dailyLog = todayLog
        context.insert(aiEntry)

        SubscriptionManager.shared.consumeFreeScanIfFreeUser()

        do {
            try context.save()
        } catch {
            return .result(
                value: "Not Logged",
                dialog: "Soma couldn't save that. Please try again."
            )
        }
        await HealthSyncService.shared.syncDay(todayLog)

        return .result(
            value: "Logged \(analysis.title)",
            dialog: "Logged \(analysis.title) with \(analysis.calories) kcal and \(Int(analysis.proteinG))g protein in Soma."
        )
    }
}

// MARK: - Action Button & Instant Launch Intents

struct SnapMealPhotoAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Snap Meal Photo with Soma AI"
    static var description = IntentDescription("Launches Soma directly into the Soma AI camera to photograph and analyze your meal.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigationState.shared.triggerAction(.camera)
        return .result()
    }
}

struct RecordVoiceMealAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Voice Meal with Soma AI"
    static var description = IntentDescription("Launches Soma and instantly starts recording your voice meal log with Soma AI.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigationState.shared.triggerAction(.voice)
        return .result()
    }
}
