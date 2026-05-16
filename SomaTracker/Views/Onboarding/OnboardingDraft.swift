import Foundation

struct OnboardingDraft {
    var name = ""
    var age = "22"
    var gender = "Male"
    var weightKG = "75"
    var heightCM = "178"
    var dailyCalorieGoal = "2000"
    var dailyWaterGoalML = "2000"
    var dailyProteinGoalG = "120"

    let defaultName = ""
    let defaultAge = 22
    let defaultGender = "Male"
    let defaultWeightKG = 75.0
    let defaultHeightCM = 178.0
    let defaultDailyCalorieGoal = 2000
    let defaultDailyWaterGoalML = 2000
    let defaultDailyProteinGoalG = 120
    let defaultActivityLevel = "Moderate"

    var resolvedName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? defaultName : trimmedName
    }

    var resolvedAge: Int {
        Int(age) ?? defaultAge
    }

    var resolvedWeightKG: Double {
        Double(weightKG) ?? defaultWeightKG
    }

    var resolvedHeightCM: Double {
        Double(heightCM) ?? defaultHeightCM
    }

    var resolvedDailyCalorieGoal: Int {
        Int(dailyCalorieGoal.replacingOccurrences(of: ",", with: "")) ?? defaultDailyCalorieGoal
    }

    var resolvedDailyWaterGoalML: Int {
        Int(dailyWaterGoalML.replacingOccurrences(of: ",", with: "")) ?? defaultDailyWaterGoalML
    }

    var resolvedDailyProteinGoalG: Int {
        Int(dailyProteinGoalG.replacingOccurrences(of: ",", with: "")) ?? defaultDailyProteinGoalG
    }
}
