import Foundation

struct StreakInfo {
    let currentStreak: Int
    let bestStreak: Int
    let hasLoggedToday: Bool
}

enum StreakCalculator {
    static func calculate(from logs: [DailyLog]) -> StreakInfo {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Set of days that have activity (calories > 0, water > 0, or steps > 0)
        let activeDates = Set(
            logs.filter { $0.totalCalories > 0 || $0.totalWater > 0 || $0.steps > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )

        let hasLoggedToday = activeDates.contains(today)

        // Calculate current streak
        var currentStreak = 0
        let startDate = hasLoggedToday ? today : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        if !hasLoggedToday && !activeDates.contains(startDate) {
            currentStreak = 0
        } else {
            var checkDate = startDate
            while activeDates.contains(checkDate) {
                currentStreak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            }
        }

        // Calculate best streak historically
        let sortedDates = activeDates.sorted()
        var bestStreak = 0
        var tempStreak = 0
        var previousDate: Date?

        for date in sortedDates {
            if let prev = previousDate {
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: prev),
                   calendar.isDate(nextDay, inSameDayAs: date) {
                    tempStreak += 1
                } else {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            bestStreak = max(bestStreak, tempStreak)
            previousDate = date
        }

        return StreakInfo(
            currentStreak: currentStreak,
            bestStreak: max(bestStreak, currentStreak),
            hasLoggedToday: hasLoggedToday
        )
    }
}
