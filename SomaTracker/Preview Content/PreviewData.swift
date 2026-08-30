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

        let calendar = Calendar.current
        let now = Date.now

        // Today's log
        let todayLog = DailyLog(date: now)
        todayLog.steps = 8432
        ctx.insert(todayLog)

        let todayBreakfastTime = calendar.date(bySettingHour: 8, minute: 15, second: 0, of: now) ?? now
        let todayLunchTime = calendar.date(bySettingHour: 12, minute: 45, second: 0, of: now) ?? now
        let todaySnackTime = calendar.date(bySettingHour: 16, minute: 10, second: 0, of: now) ?? now
        let todayDinnerTime = calendar.date(bySettingHour: 19, minute: 30, second: 0, of: now) ?? now

        let breakfast = FoodEntry(
            name: "Greek Yogurt - 170g",
            calories: 130,
            proteinG: 18.0,
            carbsG: 6.0,
            fatG: 0.0,
            mealType: "Breakfast",
            timestamp: todayBreakfastTime
        )
        let lunch = FoodEntry(
            name: "Grilled Chicken Breast - 200g",
            calories: 330,
            proteinG: 62.0,
            carbsG: 0.0,
            fatG: 7.0,
            mealType: "Lunch",
            timestamp: todayLunchTime
        )
        let snack = FoodEntry(
            name: "Avocado Toast & Egg",
            calories: 290,
            proteinG: 11.0,
            carbsG: 22.0,
            fatG: 18.0,
            mealType: "Snack",
            timestamp: todaySnackTime
        )
        let dinner = FoodEntry(
            name: "Salmon Bowl & Quinoa",
            calories: 580,
            proteinG: 42.0,
            carbsG: 46.0,
            fatG: 22.0,
            mealType: "Dinner",
            timestamp: todayDinnerTime
        )

        ctx.insert(breakfast)
        ctx.insert(lunch)
        ctx.insert(snack)
        ctx.insert(dinner)
        todayLog.foodEntries.append(contentsOf: [breakfast, lunch, snack, dinner])

        let waterTime1 = calendar.date(bySettingHour: 8, minute: 25, second: 0, of: now) ?? now
        let waterTime2 = calendar.date(bySettingHour: 10, minute: 15, second: 0, of: now) ?? now
        let waterTime3 = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: now) ?? now
        let waterTime4 = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now

        let water1 = WaterEntry(amount: 500, timestamp: waterTime1, label: "Morning Hydration")
        let water2 = WaterEntry(amount: 500, timestamp: waterTime2, label: "Post-Workout")
        let water3 = WaterEntry(amount: 400, timestamp: waterTime3, label: "Afternoon Refresher")
        let water4 = WaterEntry(amount: 350, timestamp: waterTime4, label: "Evening Hydration")

        ctx.insert(water1)
        ctx.insert(water2)
        ctx.insert(water3)
        ctx.insert(water4)
        todayLog.waterEntries.append(contentsOf: [water1, water2, water3, water4])

        // Yesterday's log
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            let yesterdayLog = DailyLog(date: yesterday)
            yesterdayLog.steps = 10120
            ctx.insert(yesterdayLog)

            let yLunch = FoodEntry(
                name: "Steak Salad & Olive Oil",
                calories: 640,
                proteinG: 48.0,
                carbsG: 12.0,
                fatG: 42.0,
                mealType: "Lunch",
                timestamp: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: yesterday) ?? yesterday
            )
            let yDinner = FoodEntry(
                name: "Brown Rice & Tofu Stir Fry",
                calories: 490,
                proteinG: 24.0,
                carbsG: 68.0,
                fatG: 14.0,
                mealType: "Dinner",
                timestamp: calendar.date(bySettingHour: 19, minute: 15, second: 0, of: yesterday) ?? yesterday
            )
            ctx.insert(yLunch)
            ctx.insert(yDinner)
            yesterdayLog.foodEntries.append(contentsOf: [yLunch, yDinner])

            let yWater1 = WaterEntry(amount: 750, timestamp: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: yesterday) ?? yesterday, label: "Morning Bottle")
            let yWater2 = WaterEntry(amount: 750, timestamp: calendar.date(bySettingHour: 15, minute: 30, second: 0, of: yesterday) ?? yesterday, label: "Afternoon Bottle")
            ctx.insert(yWater1)
            ctx.insert(yWater2)
            yesterdayLog.waterEntries.append(contentsOf: [yWater1, yWater2])
        }

        return container
    }()
}
