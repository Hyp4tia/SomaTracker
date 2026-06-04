//
//  SomaTrackerApp.swift
//  SomaTracker
//
//  Created by Zeyad Hussein on 15/05/2026.
//

import SwiftUI
import SwiftData

@main
struct SomaTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            DailyLog.self,
            FoodEntry.self,
            WaterEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The app uses a fixed navy + white brand design that isn't built
                // for dark-mode adaptation, so lock it to its intended appearance.
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
