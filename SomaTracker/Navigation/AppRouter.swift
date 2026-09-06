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
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Action Button & Deep Link Quick Actions

enum AIQuickAction: String, Sendable {
    case camera
    case voice
}

@Observable
final class AppNavigationState {
    static let shared = AppNavigationState()

    var pendingQuickAction: AIQuickAction? = nil

    @MainActor
    func triggerAction(_ action: AIQuickAction) {
        self.pendingQuickAction = action
        NotificationCenter.default.post(name: .somaTriggerQuickAction, object: action)
    }
}

extension Notification.Name {
    static let somaTriggerQuickAction = Notification.Name("somaTriggerQuickAction")
}
