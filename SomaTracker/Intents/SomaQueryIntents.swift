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

/// The metrics Soma can report on. One parameter keeps the intent list short while Siri still
/// understands "how much water" and "how many steps" as the same question with a different meter.
enum NutritionMetric: String, AppEnum {
    case calories
    case protein
    case water
    case steps

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Nutrition Metric"

    static var caseDisplayRepresentations: [NutritionMetric: DisplayRepresentation] = [
        .calories: "Calories",
        .protein: "Protein",
        .water: "Water",
        .steps: "Steps"
    ]
}

/// Today's numbers, read through the same models the app writes. Answers are built here rather than
/// in each intent so a Siri reply and the History screen can never disagree.
@MainActor
private struct SomaToday {
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
            let remaining = max(0, calorieGoal - consumed)
            return remaining == 0
                ? "You've reached your \(calorieGoal.formatted()) kcal goal, with \(consumed.formatted()) consumed."
                : "\(remaining.formatted()) kcal left today. \(consumed.formatted()) of \(calorieGoal.formatted()) consumed."

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
        }
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
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let today = SomaToday(context: SomaPersistence.shared.mainContext)
        let answer = today.answer(for: metric)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}

struct GetStreakStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Soma Streak"
    static var description = IntentDescription("Reports your current streak and whether today is logged yet.")

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let context = SomaPersistence.shared.mainContext
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        let streak = StreakCalculator.calculate(from: logs)

        let answer: String
        if streak.currentStreak == 0 {
            answer = "No streak yet. Log a meal, some water, or your steps today to start one."
        } else if streak.hasLoggedToday {
            answer = "You're on a \(streak.currentStreak) day streak and today is already logged. Your best is \(streak.bestStreak) days."
        } else {
            answer = "Your streak is \(streak.currentStreak) days. Nothing logged today yet."
        }

        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
}
