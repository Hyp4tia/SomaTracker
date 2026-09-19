//
//  SomaQueryIntents.swift
//  SomaTracker
//
//  Read intents: they answer questions about today from the Lock Screen without opening the app,
//  and they never modify anything. "Hey Siri, how many calories do I have left in Soma?"
//

import AppIntents
import Foundation
import SwiftData
// The result builders that attach a view to an intent live in this glue module, and SwiftUI does not
// re-export it, so a snippet-returning intent has to name it.
import _AppIntents_SwiftUI

/// The metrics Soma can report on. One parameter keeps the intent list short while Siri still
/// understands "how much water" and "how many steps" as the same question with a different meter.
enum NutritionMetric: String, AppEnum {
    case calories
    case protein
    case water
    case steps
    case summary

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Nutrition Metric"

    static var caseDisplayRepresentations: [NutritionMetric: DisplayRepresentation] = [
        .calories: "Calories",
        .protein: "Protein",
        .water: "Water",
        .steps: "Steps",
        .summary: "Everything"
    ]
}

/// Today's numbers, read through the same models the app writes. Answers are built here rather than
/// in each intent so a Siri reply and the History screen can never disagree.
@MainActor
struct SomaToday {
    private let log: DailyLog?
    private let profile: UserProfile?

    init(context: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { log in
                log.date >= startOfDay && log.date < nextDay
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        self.log = (try? context.fetch(descriptor))?.first
        self.profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
    }

    private var calorieGoal: Int { profile?.dailyCalorieGoal ?? 2_000 }
    private var proteinGoal: Int { profile?.dailyProteinGoalG ?? 120 }
    private var waterGoalML: Int { profile?.dailyWaterGoalML ?? 2_000 }
    private var stepGoal: Int { profile?.dailyStepGoal ?? 10_000 }

    func answer(for metric: NutritionMetric) -> String {
        switch metric {
        case .calories:
            let consumed = log?.totalCalories ?? 0
            guard consumed > 0 else {
                return "Nothing logged yet today. Your goal is \(calorieGoal.formatted()) kcal."
            }
            // Consumed first: "how many calories did I eat" and "how many do I have left" are the
            // same question from two sides, and one answer carries both.
            let remaining = calorieGoal - consumed
            if remaining < 0 {
                return "You've eaten \(consumed.formatted()) kcal today, \((-remaining).formatted()) past your \(calorieGoal.formatted()) kcal goal."
            }
            return "You've eaten \(consumed.formatted()) of your \(calorieGoal.formatted()) kcal goal today, \(remaining.formatted()) left."

        case .protein:
            let consumed = Int((log?.totalProtein ?? 0).rounded())
            let remaining = max(0, proteinGoal - consumed)
            return "\(consumed) of \(proteinGoal) grams of protein, \(remaining) to go."

        case .water:
            let system = SomaToday.unitSystem
            let consumed = log?.totalWater ?? 0
            let unit = Units.waterUnit(system)
            return "\(Units.waterValue(ml: consumed, system: system).formatted()) of \(Units.waterValue(ml: waterGoalML, system: system).formatted()) \(unit) of water today."

        case .steps:
            return "\((log?.steps ?? 0).formatted()) of \(stepGoal.formatted()) steps today."

        case .summary:
            let consumed = log?.totalCalories ?? 0
            guard consumed > 0 else {
                return "Nothing logged yet today. Your goal is \(calorieGoal.formatted()) kcal."
            }
            let protein = Int((log?.totalProtein ?? 0).rounded())
            let system = SomaToday.unitSystem
            let water = Units.waterValue(ml: log?.totalWater ?? 0, system: system)
            let unit = Units.waterUnit(system)
            let remaining = max(0, calorieGoal - consumed)
            return "Today: \(consumed.formatted()) of \(calorieGoal.formatted()) kcal, \(protein) grams of protein, and \(water.formatted()) \(unit) of water. \(remaining.formatted()) kcal left."
        }
    }

    /// One line of today's numbers, for the chat header. Siri gets the full sentence; the chat only has
    /// room for the two that matter most.
    var compactSummary: String {
        let consumed = log?.totalCalories ?? 0
        let remaining = calorieGoal - consumed
        let proteinLeft = max(0, proteinGoal - Int((log?.totalProtein ?? 0).rounded()))

        if consumed == 0 {
            return SpeechLanguage.resolved() == .arabic ? "لسه مفيش حاجة متسجلة النهاردة" : "Nothing logged today yet"
        }

        if SpeechLanguage.resolved() == .arabic {
            return remaining >= 0
                ? "باقي \(remaining.formatted()) كالوري · \(proteinLeft) جرام بروتين"
                : "عدّيت هدفك بـ \((-remaining).formatted()) كالوري · \(proteinLeft) جرام بروتين باقي"
        }
        return remaining >= 0
            ? "\(remaining.formatted()) kcal left · \(proteinLeft) g protein left"
            : "\((-remaining).formatted()) kcal over · \(proteinLeft) g protein left"
    }

    /// The same words the Siri intent answers with, so a spoken answer and a typed one cannot disagree.
    static func streakAnswer(context: ModelContext) -> String {
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        let streak = StreakCalculator.calculate(from: logs)

        if streak.currentStreak == 0 {
            return "No streak yet. Log a meal, some water, or your steps today to start one."
        }
        if streak.hasLoggedToday {
            return "You're on a \(streak.currentStreak) day streak and today is already logged. Your best is \(streak.bestStreak) days."
        }
        return "Your streak is \(streak.currentStreak) days. Nothing logged today yet."
    }

    /// The same numbers the spoken answer is built from, so the card and the dialog cannot disagree.
    var daySnippet: SomaDaySnippetView {
        let system = SomaToday.unitSystem
        return SomaDaySnippetView(
            calories: log?.totalCalories ?? 0,
            calorieGoal: calorieGoal,
            protein: log?.totalProtein ?? 0,
            proteinGoal: Double(proteinGoal),
            water: Units.waterValue(ml: log?.totalWater ?? 0, system: system),
            waterGoal: Units.waterValue(ml: waterGoalML, system: system),
            waterUnit: Units.waterUnit(system),
            steps: log?.steps ?? 0,
            stepGoal: stepGoal
        )
    }

    /// The stored preference the views read too, so spoken and printed units match.
    static var unitSystem: UnitSystem {
        let stored = UserDefaults.standard.string(forKey: Units.storageKey)
        return UnitSystem(rawValue: stored ?? "") ?? .metric
    }
}

struct GetDailyNutritionIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Today in Soma"
    static var description = IntentDescription("Asks how today is going: calories left, protein, water, or steps.")

    @Parameter(title: "Metric", default: .calories)
    var metric: NutritionMetric

    static var parameterSummary: some ParameterSummary {
        Summary("Check \(\.$metric) in Soma")
    }

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> & ShowsSnippetView {
        let today = SomaToday(context: SomaPersistence.shared.mainContext)
        let answer = today.answer(for: metric)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer), view: today.daySnippet)
    }
}

/// Its own intent rather than a metric value: Siri can bind an enum parameter only from a spoken
/// phrase it recognises, so "how is my day" would have no reliable way to select a summary.
struct GetDailySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Whole Day in Soma"
    static var description = IntentDescription("Reports calories, protein and water for today in one answer.")

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> & ShowsSnippetView {
        let today = SomaToday(context: SomaPersistence.shared.mainContext)
        let answer = today.answer(for: .summary)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer), view: today.daySnippet)
    }
}

struct GetStreakStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Soma Streak"
    static var description = IntentDescription("Reports your current streak and whether today is logged yet.")

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> & ShowsSnippetView {
        let context = SomaPersistence.shared.mainContext
        let answer = SomaToday.streakAnswer(context: context)
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        let streak = StreakCalculator.calculate(from: logs)

        return .result(
            value: answer,
            dialog: IntentDialog(stringLiteral: answer),
            view: SomaStreakSnippetView(
                current: streak.currentStreak,
                best: streak.bestStreak,
                loggedToday: streak.hasLoggedToday
            )
        )
    }
}
