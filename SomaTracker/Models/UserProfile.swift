//
//  UserProfile.swift
//  SomaTracker
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var age: Int
    var gender: String
    var weightKG: Double
    var heightCM: Double
    var activityLevel: String
    var dailyCalorieGoal: Int
    var dailyWaterGoalML: Int
    var dailyProteinGoalG: Int
    var createdAt: Date

    init(
        name: String,
        age: Int,
        gender: String,
        weightKG: Double,
        heightCM: Double,
        activityLevel: String,
        dailyCalorieGoal: Int = 2000,
        dailyWaterGoalML: Int = 2000,
        dailyProteinGoalG: Int = 120
    ) {
        self.name = name
        self.age = age
        self.gender = gender
        self.weightKG = weightKG
        self.heightCM = heightCM
        self.activityLevel = activityLevel
        self.dailyCalorieGoal = dailyCalorieGoal
        self.dailyWaterGoalML = dailyWaterGoalML
        self.dailyProteinGoalG = dailyProteinGoalG
        self.createdAt = .now
    }
}
