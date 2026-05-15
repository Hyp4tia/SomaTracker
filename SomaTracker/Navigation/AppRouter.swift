//
//  AppRouter.swift
//  SomaTracker
//

import Foundation
import Observation

@Observable
final class AppRouter {
    var showLogSheet: Bool = false

    // Stored var so @Observable can track it — a computed getter reading UserDefaults
    // would be invisible to the observation system and views would never re-render.
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    init() {
        self.hasCompletedOnboarding = true // TEMP: bypass onboarding for UI testing
    }
}
