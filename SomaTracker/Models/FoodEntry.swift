//
//  FoodEntry.swift
//  SomaTracker
//

import Foundation
import SwiftData

@Model
final class FoodEntry {
    var name: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double = 0.0
    var fatG: Double = 0.0
    var mealType: String
    var timestamp: Date
    var dailyLog: DailyLog?
    var aiMealEntryId: UUID? = nil

    /// Calculates accurate minimum calories from macronutrient content (1g Protein = 4 kcal, 1g Carb = 4 kcal, 1g Fat = 9 kcal)
    var effectiveCalories: Int {
        let macroCalories = Int(round(proteinG * 4.0 + carbsG * 4.0 + fatG * 9.0))
        return max(calories, macroCalories)
    }

    init(
        name: String,
        calories: Int = 0,
        proteinG: Double = 0,
        carbsG: Double = 0,
        fatG: Double = 0,
        mealType: String = "",
        timestamp: Date = .now,
        aiMealEntryId: UUID? = nil
    ) {
        self.name = name
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.mealType = mealType
        self.timestamp = timestamp
        self.aiMealEntryId = aiMealEntryId
        
        let calculatedMacroKcal = Int(round(proteinG * 4.0 + carbsG * 4.0 + fatG * 9.0))
        self.calories = max(calories, calculatedMacroKcal)
    }
}

extension FoodEntry {
    /// Deletes the food entry from its daily log and cleans up any linked AIMealEntry & audio file.
    func deleteWithSyncedAIEntry(from log: DailyLog?, in context: ModelContext) {
        log?.foodEntries.removeAll { $0.id == self.id }

        let targetAiId = self.aiMealEntryId
        let entryTime = self.timestamp
        let entryCalories = self.calories
        let entryName = self.name
        let entryMealType = self.mealType

        let descriptor = FetchDescriptor<AIMealEntry>()
        if let aiEntries = try? context.fetch(descriptor) {
            for aiMeal in aiEntries {
                let isMatchById = (targetAiId != nil && aiMeal.id == targetAiId)
                let isMatchByHeuristic = targetAiId == nil &&
                    (entryMealType.contains("AI") || entryMealType.contains("Voice") || entryMealType.contains("Photo")) &&
                    abs(aiMeal.timestamp.timeIntervalSince(entryTime)) < 120 &&
                    aiMeal.calories == entryCalories &&
                    (aiMeal.title == entryName || entryName.contains("AI Meal"))

                if isMatchById || isMatchByHeuristic {
                    if let relPath = aiMeal.voiceAudioRelativePath {
                        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        try? FileManager.default.removeItem(at: docs.appendingPathComponent(relPath))
                    }
                    context.delete(aiMeal)
                }
            }
        }

        context.delete(self)
        try? context.save()
    }
}
