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

    var totalCalories: Int { foodEntries.reduce(0) { $0 + $1.effectiveCalories } }
    var totalProtein: Double { foodEntries.reduce(0.0) { $0 + $1.proteinG } }
    var totalCarbs: Double { foodEntries.reduce(0.0) { $0 + $1.carbsG } }
    var totalFat: Double { foodEntries.reduce(0.0) { $0 + $1.fatG } }
    var totalWater: Int { waterEntries.reduce(0) { $0 + $1.amount } }

    init(date: Date, steps: Int = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
    }

    static func fetchOrCreateToday(context: ModelContext) -> DailyLog {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            let fallback = DailyLog(date: startOfDay)
            context.insert(fallback)
            return fallback
        }

        let predicate = #Predicate<DailyLog> { log in
            log.date >= startOfDay && log.date < nextDay
        }
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        if let matches = try? context.fetch(descriptor), !matches.isEmpty {
            if matches.count > 1 {
                return mergeDuplicates(matches, context: context)
            }
            return matches[0]
        }

        let log = DailyLog(date: startOfDay)
        context.insert(log)
        return log
    }

    @discardableResult
    static func mergeDuplicates(_ logs: [DailyLog], context: ModelContext) -> DailyLog {
        guard let primary = logs.first else {
            fatalError("mergeDuplicates called with empty array")
        }
        if logs.count == 1 { return primary }

        let calendar = Calendar.current
        primary.date = calendar.startOfDay(for: primary.date)

        for duplicate in logs.dropFirst() {
            primary.steps = max(primary.steps, duplicate.steps)

            let movingFoods = duplicate.foodEntries
            duplicate.foodEntries = []
            for food in movingFoods {
                food.dailyLog = primary
                if !primary.foodEntries.contains(where: { $0 === food }) {
                    primary.foodEntries.append(food)
                }
            }

            let movingWater = duplicate.waterEntries
            duplicate.waterEntries = []
            for water in movingWater {
                water.dailyLog = primary
                if !primary.waterEntries.contains(where: { $0 === water }) {
                    primary.waterEntries.append(water)
                }
            }

            // Migrate any linked AI journal entries before deleting duplicate
            let aiDescriptor = FetchDescriptor<AIMealEntry>()
            if let allAiEntries = try? context.fetch(aiDescriptor) {
                for aiEntry in allAiEntries where aiEntry.dailyLog === duplicate {
                    aiEntry.dailyLog = primary
                }
            }

            context.delete(duplicate)
        }

        try? context.save()
        return primary
    }

    static func deduplicateAllLogs(context: ModelContext) {
        let descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .forward)])
        guard let allLogs = try? context.fetch(descriptor), !allLogs.isEmpty else { return }

        let calendar = Calendar.current
        var logsByDay: [Date: [DailyLog]] = [:]

        for log in allLogs {
            let dayKey = calendar.startOfDay(for: log.date)
            logsByDay[dayKey, default: []].append(log)
        }

        var didModify = false
        for (_, dayLogs) in logsByDay where dayLogs.count > 1 {
            _ = mergeDuplicates(dayLogs, context: context)
            didModify = true
        }

        if didModify {
            try? context.save()
        }
    }
}
