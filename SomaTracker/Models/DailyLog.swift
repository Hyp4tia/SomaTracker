//
//  DailyLog.swift
//  SomaTracker
//

import Foundation
import SwiftData

@Model
final class DailyLog {
    var date: Date
    var steps: Int

    @Relationship(deleteRule: .cascade, inverse: \FoodEntry.dailyLog)
    var foodEntries: [FoodEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \WaterEntry.dailyLog)
    var waterEntries: [WaterEntry] = []

    var totalCalories: Int { foodEntries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { foodEntries.reduce(0.0) { $0 + $1.proteinG } }
    var totalWater: Int { waterEntries.reduce(0) { $0 + $1.amount } }

    init(date: Date, steps: Int = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
    }

    static func fetchOrCreateToday(context: ModelContext) -> DailyLog {
        let today = Calendar.current.startOfDay(for: .now)
        let predicate = #Predicate<DailyLog> { $0.date == today }
        let descriptor = FetchDescriptor<DailyLog>(predicate: predicate)

        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }

        let log = DailyLog(date: today)
        context.insert(log)
        return log
    }
}
