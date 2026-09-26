import Foundation
import SwiftData

@MainActor
enum SomaChatLogWriter {
    struct Written {
        let aiEntry: AIMealEntry
        let foodEntry: FoodEntry
        let day: DailyLog
    }

    static func writeMeal(
        _ analysis: AIMealAnalysisResult,
        input: String,
        photos: [Data] = [],
        context: ModelContext
    ) -> Written? {
        let day = DailyLog.fetchOrCreateToday(context: context)
        let id = UUID()
        let food = FoodEntry(
            name: analysis.title,
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            mealType: "Soma Chat",
            timestamp: .now,
            aiMealEntryId: id
        )
        day.foodEntries.append(food)

        let entry = AIMealEntry(
            id: id,
            title: analysis.title,
            location: analysis.location,
            storyText: input,
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            photoDataList: photos,
            breakdownNotes: analysis.storyNarrative
        )
        entry.dailyLog = day
        context.insert(entry)

        if let water = WaterEntry.loggedWithMeal(analysis.waterML, linkedTo: id) {
            day.waterEntries.append(water)
        }

        do {
            try context.save()
            return Written(aiEntry: entry, foodEntry: food, day: day)
        } catch {
            context.rollback()
            return nil
        }
    }

    static func writeWater(amountML: Int, input: String, summary: String, context: ModelContext) -> AIMealEntry? {
        let entry = AIMealEntry.logHydration(
            amountML: amountML,
            story: input,
            summary: summary,
            in: context
        )
        do {
            try context.save()
            return entry
        } catch {
            context.rollback()
            return nil
        }
    }
}
