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
    var mealType: String
    var timestamp: Date
    var dailyLog: DailyLog?

    init(
        name: String,
        calories: Int,
        proteinG: Double,
        mealType: String,
        timestamp: Date = .now
    ) {
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.mealType = mealType
        self.timestamp = timestamp
    }
}
