//
//  SomaSpotlightIndexer.swift
//  SomaTracker
//
//  Keeps logged meals in the system semantic index so Spotlight, and the new Siri, can find them by
//  meaning rather than exact words. iOS 18 and later; older systems simply skip it.
//

import AppIntents
import CoreSpotlight
import Foundation
import SwiftData

enum SomaSpotlightIndexer {
    /// What was written last time, so meals deleted in Soma can be removed from the index too.
    private static let indexedKey = "soma_spotlight_identifiers"

    /// Re-indexes recent meals and clears anything that no longer exists. Idempotent and cheap, so
    /// it is safe to call after any save.
    /// The context comes from the caller: a default argument cannot reach the shared container
    /// because default values are evaluated outside the main actor.
    @MainActor
    static func sync(context: ModelContext) async {
        guard #available(iOS 18.0, *) else { return }

        let meals = SomaMeals.recent(limit: 100, context: context)
        let current = Set(meals.map(\.id))
        let previous = Set(UserDefaults.standard.stringArray(forKey: indexedKey) ?? [])
        let removed = previous.subtracting(current)

        do {
            let index = CSSearchableIndex.default()
            if !removed.isEmpty {
                try await index.deleteAppEntities(identifiedBy: Array(removed), ofType: MealAppEntity.self)
            }
            try await index.indexAppEntities(meals)
            UserDefaults.standard.set(Array(current), forKey: indexedKey)
        } catch {
            // A failed index update must never disturb logging, so it stays a log line.
            print("[Spotlight] Index update failed: \(error.localizedDescription)")
        }
    }
}
