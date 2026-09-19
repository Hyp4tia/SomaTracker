//
//  SomaDayContext.swift
//  SomaTracker
//
//  A compact picture of the user's own numbers, built from the same store every other screen reads.
//  Advice is only worth having if it is about this person's day, so nothing here is invented: the
//  digest is the model's entire world, and it is told to use only what it is given.
//

import Foundation
import SwiftData

struct SomaDayContext {
    let calorieGoal: Int
    let proteinGoal: Int
    let waterGoalML: Int
    let stepGoal: Int

    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let waterML: Int
    let steps: Int

    let streak: Int
    let loggedToday: Bool

    /// The last few dishes, newest first, with what they were worth.
    let recentMeals: [String]
    /// What this person actually eats, counted over the last month, most frequent first.
    let favourites: [String]
    /// The same favourites as bare names, for matching a suggestion to what someone likes.
    let favouriteNames: [String]
    /// What was already eaten today, so nothing is suggested twice.
    let todayTitles: [String]
    /// Days logged and the average calories over the last week.
    let weekDaysLogged: Int
    let weekAverageCalories: Int

    /// Real dishes, with their real numbers, worth suggesting for what is left of the day. Built by
    /// SomaFoodSuggestion from the app's own database.
    let suggestions: [String]

    var remainingCalories: Int { max(0, calorieGoal - calories) }
    var remainingProteinG: Int { max(0, proteinGoal - Int(proteinG.rounded())) }
    var remainingWaterML: Int { max(0, waterGoalML - waterML) }

    /// What the models are given. Every line is a fact from the store, and the instruction above it
    /// forbids inventing others.
    var promptDigest: String {
        var lines: [String] = [
            "The user's own numbers. Never invent numbers that are not here.",
            "- Daily goals: \(calorieGoal) kcal, \(proteinGoal) g protein, \(waterGoalML) ml water, \(stepGoal) steps",
            "- Eaten today: \(calories) kcal, \(Int(proteinG.rounded())) g protein, \(Int(carbsG.rounded())) g carbs, \(Int(fatG.rounded())) g fat",
            "- Left today: \(remainingCalories) kcal, \(remainingProteinG) g protein",
            "- Water today: \(waterML) ml of \(waterGoalML) ml. Steps: \(steps) of \(stepGoal)",
            "- Streak: \(streak) day(s). Today is \(loggedToday ? "already logged" : "not logged yet")"
        ]

        if !todayTitles.isEmpty {
            lines.append("- Eaten today: \(todayTitles.joined(separator: ", "))")
        }
        if !recentMeals.isEmpty {
            lines.append("- Last logged overall: \(recentMeals.joined(separator: "; "))")
        }
        if !favourites.isEmpty {
            lines.append("- Eaten most often in the last 30 days: \(favourites.joined(separator: ", "))")
        }
        if !suggestions.isEmpty {
            lines.append("- Soma's own options, exact numbers, none of them eaten today: \(suggestions.joined(separator: ", "))")
        }
        if weekDaysLogged > 0 {
            lines.append("- Last 7 days: \(weekDaysLogged) day(s) logged, averaging \(weekAverageCalories) kcal a day")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Building

    /// Reads the store once and returns the picture. Cheap enough to call per question: a handful of
    /// fetches over an indexed date range, no writes.
    @MainActor
    static func build(context: ModelContext) -> SomaDayContext {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: startOfDay) ?? startOfDay
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfDay) ?? startOfDay

        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first

        let todayDescriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { log in log.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let today = (try? context.fetch(todayDescriptor))?.first

        // Bounded: this used to fetch every DailyLog the user has ever had, on every advice question.
        // 400 days is longer than any streak the calculator can report.
        let historyStart = calendar.date(byAdding: .day, value: -400, to: startOfDay) ?? startOfDay
        let historyDescriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { log in log.date >= historyStart },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let allLogs = (try? context.fetch(historyDescriptor)) ?? []
        let streak = StreakCalculator.calculate(from: allLogs)

        let weekLogs = allLogs.filter { $0.date >= weekAgo }
        let weekAverage = weekLogs.isEmpty
            ? 0
            : weekLogs.reduce(0) { $0 + $1.totalCalories } / max(1, weekLogs.count)

        let recentDescriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate<FoodEntry> { entry in entry.timestamp >= monthAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let recentEntries = (try? context.fetch(recentDescriptor)) ?? []

        let recentMeals = recentEntries
            .prefix(3)
            .map { "\($0.name) (\($0.calories) kcal)" }

        // Frequency is the best signal the app has for "what this person likes"; there are no ratings.
        var counts: [String: (count: Int, calories: Int)] = [:]
        for entry in recentEntries {
            let key = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            let existing = counts[key] ?? (0, entry.calories)
            counts[key] = (existing.count + 1, entry.calories)
        }
        let ranked = counts
            .sorted { $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count }
        let favouriteNames = ranked.prefix(6).map(\.key)
        let favourites = ranked
            .filter { $0.value.count >= 2 }
            .prefix(6)
            .map { "\($0.key) (\($0.value.count)x, \($0.value.calories) kcal)" }
        let todayTitles = recentEntries
            .filter { $0.timestamp >= startOfDay }
            .map(\.name)

        let calorieGoal = profile?.dailyCalorieGoal ?? 2_000
        let proteinGoal = profile?.dailyProteinGoalG ?? 120
        let suggestions = SomaFoodSuggestion.candidates(
            remainingCalories: max(0, calorieGoal - (today?.totalCalories ?? 0)),
            remainingProteinG: max(0, proteinGoal - Int((today?.totalProtein ?? 0).rounded())),
            favouriteNames: favouriteNames,
            todayTitles: todayTitles
        )

        return SomaDayContext(
            calorieGoal: profile?.dailyCalorieGoal ?? 2_000,
            proteinGoal: profile?.dailyProteinGoalG ?? 120,
            waterGoalML: profile?.dailyWaterGoalML ?? 2_000,
            stepGoal: profile?.dailyStepGoal ?? 10_000,
            calories: today?.totalCalories ?? 0,
            proteinG: today?.totalProtein ?? 0,
            carbsG: today?.totalCarbs ?? 0,
            fatG: today?.totalFat ?? 0,
            waterML: today?.totalWater ?? 0,
            steps: today?.steps ?? 0,
            streak: streak.currentStreak,
            loggedToday: streak.hasLoggedToday,
            recentMeals: Array(recentMeals),
            favourites: Array(favourites),
            favouriteNames: favouriteNames,
            todayTitles: todayTitles,
            weekDaysLogged: weekLogs.filter { $0.totalCalories > 0 }.count,
            weekAverageCalories: weekAverage,
            suggestions: suggestions
        )
    }
}
