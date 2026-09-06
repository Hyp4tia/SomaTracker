//
//  SomaIntents.swift
//  SomaTracker
//
//  Audited App Intents providing seamless Apple Intelligence & Siri integration
//  for natural commands like "log 100 water", "log 500 calories", "log big mac".
//

import AppIntents
import SwiftData
import Foundation

struct LogWaterAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water in Soma"
    static var description = IntentDescription("Log water intake into Soma (e.g. 'log 100 water' means 100 ml).")

    @Parameter(title: "Amount", default: 250)
    var amount: Int

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let schema = Schema([UserProfile.self, DailyLog.self, FoodEntry.self, WaterEntry.self, AIMealEntry.self])
        guard let container = try? ModelContainer(for: schema) else {
            return .result(value: "Failed", dialog: "Could not open Soma database.")
        }
        let context = container.mainContext
        let todayLog = DailyLog.fetchOrCreateToday(context: context)

        let targetML = max(1, amount)
        let entry = WaterEntry(amount: targetML, timestamp: .now, label: "Siri AI")
        todayLog.waterEntries.append(entry)
        try? context.save()

        return .result(
            value: "Logged \(targetML) ml",
            dialog: "Added \(targetML) ml of water to your daily hydration in Soma."
        )
    }
}

struct LogMealAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Food & Nutrition in Soma"
    static var description = IntentDescription("Log any meal, calories, or protein using natural speech (e.g. 'log a Big Mac', 'log 500 calories', 'log 40 protein').")

    @Parameter(title: "Food or Nutrition Description")
    var item: String

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let schema = Schema([UserProfile.self, DailyLog.self, FoodEntry.self, WaterEntry.self, AIMealEntry.self])
        guard let container = try? ModelContainer(for: schema) else {
            return .result(value: "Failed", dialog: "Could not open Soma database.")
        }
        let context = container.mainContext
        let todayLog = DailyLog.fetchOrCreateToday(context: context)

        // 1. First check if user is logging water: "log 100 water", "سجل ١٠٠ مية"
        let waterCheck = FoodNutritionDatabase.shared.parseInput(item)
        if waterCheck.isWater {
            let waterEntry = WaterEntry(amount: waterCheck.waterML, timestamp: .now, label: "Siri AI")
            todayLog.waterEntries.append(waterEntry)
            try? context.save()
            return .result(
                value: "Logged \(waterCheck.waterML) ml",
                dialog: "Added \(waterCheck.waterML) ml of water to your daily hydration in Soma."
            )
        }

        // 2. Parse meal using AIRouter (routes through Gemini 2.0 Flash if API key is active, or local engine)
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
            mealType: "Siri AI",
            timestamp: .now
        )
        todayLog.foodEntries.append(foodEntry)

        // 4. Also create an AIMealEntry so it surfaces in the AI Journal
        let aiEntry = AIMealEntry(
            title: analysis.title,
            location: "Logged via Siri AI",
            storyText: "Quickly captured via Siri: \"\(item)\".",
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            breakdownNotes: analysis.storyNarrative
        )
        aiEntry.dailyLog = todayLog
        context.insert(aiEntry)

        try? context.save()

        return .result(
            value: "Logged \(analysis.title)",
            dialog: "Logged \(analysis.title) with \(analysis.calories) kcal and \(Int(analysis.proteinG))g protein in Soma."
        )
    }
}
