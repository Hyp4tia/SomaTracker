//
//  PreviewData.swift
//  SomaTracker
//

import Foundation
import SwiftData

@MainActor
struct PreviewData {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: UserProfile.self, DailyLog.self, FoodEntry.self, WaterEntry.self,
            configurations: config
        )
        let ctx = container.mainContext

        let profile = UserProfile(
            name: "Alex",
            age: 28,
            gender: "Male",
            weightKG: 75.0,
            heightCM: 178.0,
            activityLevel: "Moderate"
        )
        ctx.insert(profile)

        let log = DailyLog(date: .now)
        log.steps = 8432
        ctx.insert(log)

        let oatmeal = FoodEntry(name: "Oatmeal", calories: 350, proteinG: 12.0, mealType: "Breakfast")
        let chickenSalad = FoodEntry(name: "Chicken Salad", calories: 520, proteinG: 45.0, mealType: "Lunch")
        ctx.insert(oatmeal)
        ctx.insert(chickenSalad)
        log.foodEntries.append(contentsOf: [oatmeal, chickenSalad])

        let water1 = WaterEntry(amount: 250)
        let water2 = WaterEntry(amount: 500)
        ctx.insert(water1)
        ctx.insert(water2)
        log.waterEntries.append(contentsOf: [water1, water2])

        return container
    }()
}
