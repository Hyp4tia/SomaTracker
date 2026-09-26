import Foundation
import SwiftData

@MainActor
struct SomaDayAnswers {
    private let log: DailyLog?
    private let profile: UserProfile?
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { $0.date >= start && $0.date < end }
        )
        log = (try? context.fetch(descriptor))?.first
        profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
    }

    func answer(for metric: SomaChatMetric) -> String {
        switch metric {
        case .calories:
            let consumed = log?.totalCalories ?? 0
            let goal = profile?.dailyCalorieGoal ?? 2_000
            let remaining = goal - consumed
            return remaining >= 0
                ? "You've eaten \(consumed) of \(goal) kcal today, with \(remaining) left."
                : "You've eaten \(consumed) kcal today, \(-remaining) over your goal."

        case .protein:
            let consumed = Int((log?.totalProtein ?? 0).rounded())
            let goal = profile?.dailyProteinGoalG ?? 120
            return "You're at \(consumed) of \(goal) g protein, with \(max(0, goal - consumed)) g left."

        case .water:
            let consumed = log?.totalWater ?? 0
            let goal = profile?.dailyWaterGoalML ?? 2_000
            return "You've had \(consumed) of \(goal) ml of water today."

        case .steps:
            let steps = log?.steps ?? 0
            let goal = profile?.dailyStepGoal ?? 10_000
            return "You've taken \(steps) of your \(goal) step goal today."

        case .summary:
            let calories = log?.totalCalories ?? 0
            let goal = profile?.dailyCalorieGoal ?? 2_000
            let protein = Int((log?.totalProtein ?? 0).rounded())
            let water = log?.totalWater ?? 0
            return "Today: \(calories) of \(goal) kcal, \(protein) g protein, and \(water) ml water."
        }
    }

    var streakAnswer: String {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: .now)) ?? .distantPast
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate<DailyLog> { $0.date >= start })
        let streak = StreakCalculator.calculate(from: (try? context.fetch(descriptor)) ?? [])
        if streak.currentStreak == 0 {
            return "No streak yet. Log food, water, or steps today to start one."
        }
        return "Your current streak is \(streak.currentStreak) days, and your best is \(streak.bestStreak) days."
    }

    var todayAnswer: String {
        let entries = log?.foodEntries.sorted { $0.timestamp < $1.timestamp } ?? []
        guard !entries.isEmpty else {
            return "You haven't logged any food today."
        }
        let list = entries.map { "\($0.name) (\($0.effectiveCalories) kcal)" }.joined(separator: ", ")
        return "Today you've logged: \(list)."
    }

    var promptContext: String {
        let calories = log?.totalCalories ?? 0
        let protein = Int((log?.totalProtein ?? 0).rounded())
        let water = log?.totalWater ?? 0
        let meals = log?.foodEntries.map(\.name).joined(separator: ", ") ?? "None"
        return """
        User goals: \(profile?.dailyCalorieGoal ?? 2_000) kcal, \(profile?.dailyProteinGoalG ?? 120) g protein, \(profile?.dailyWaterGoalML ?? 2_000) ml water.
        Today: \(calories) kcal, \(protein) g protein, \(water) ml water.
        Meals today: \(meals.isEmpty ? "None" : meals).
        """
    }
}
