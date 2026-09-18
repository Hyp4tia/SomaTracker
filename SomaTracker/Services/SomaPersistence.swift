//
//  SomaPersistence.swift
//  SomaTracker
//
//  Single source of truth for the SwiftData stack.
//

import Foundation
import SwiftData

/// One schema + one container for the whole app.
///
/// App Intents run inside the app's own process, so every intent context has to come
/// from here rather than building a second `ModelContainer` over the same store file.
enum SomaPersistence {
    static let schema = Schema([
        UserProfile.self,
        DailyLog.self,
        FoodEntry.self,
        WaterEntry.self,
        AIMealEntry.self,
    ])

    static func makeContainer() -> ModelContainer? {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try? ModelContainer(for: schema, configurations: [configuration])
    }

    static let shared: ModelContainer = {
        guard let container = makeContainer() else {
            fatalError("Could not create ModelContainer")
        }
        return container
    }()
}
