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
        timestamp: Date = .now
    ) {
        self.name = name
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.mealType = mealType
        self.timestamp = timestamp
        
        let calculatedMacroKcal = Int(round(proteinG * 4.0 + carbsG * 4.0 + fatG * 9.0))
        self.calories = max(calories, calculatedMacroKcal)
    }
}
