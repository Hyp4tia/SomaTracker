//
//  DevAccessManager.swift
//  SomaTracker
//
//  Temporary developer code unlock for beta testing.
//
//  -------------------------------------------------------------------------
//  HOW TO REMOVE THIS IN THE FUTURE:
//  Option A (Quick disable):
//    Set `isEnabled = false` below.
//
//  Option B (Complete removal):
//    1. Delete this file (`DevAccessManager.swift`).
//    2. In `SubscriptionManager.swift`, remove the marked `// MARK: - Dev Access` block
//       and `DevAccessManager.isDevAccessActive` references.
//    3. In `SomaPaywallView.swift`, remove the marked `// MARK: - Dev Redeem Code` block.
//  -------------------------------------------------------------------------
//

import Foundation

enum DevRedeemResult {
    case unlocked
    case revoked
    case invalid
}

enum DevAccessManager {
    /// Kill switch: set to `false` to immediately deactivate dev access and codes.
    static let isEnabled: Bool = true

    /// Secret hardcoded testing code that unlocks all AI features.
    static let devPasscode: String = "dev67"

    /// Persistence key in standard UserDefaults.
    private static let devAccessKey = "soma_dev_ai_unlocked"

    /// Whether developer access is currently active.
    static var isDevAccessActive: Bool {
        guard isEnabled else { return false }
        return UserDefaults.standard.bool(forKey: devAccessKey)
    }

    /// Validates code and updates status. Case-insensitive and whitespace-tolerant.
    static func redeem(code: String) -> DevRedeemResult {
        guard isEnabled else { return .invalid }
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if clean == devPasscode.lowercased() {
            UserDefaults.standard.set(true, forKey: devAccessKey)
            return .unlocked
        } else if clean == "reset" || clean == "revoke" {
            revokeAccess()
            return .revoked
        }

        return .invalid
    }

    /// Revokes developer access (useful for returning to locked testing state).
    static func revokeAccess() {
        UserDefaults.standard.removeObject(forKey: devAccessKey)
    }
}
