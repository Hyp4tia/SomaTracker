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
    var sharedModelContainer: ModelContainer = SomaPersistence.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The app uses a fixed navy + white brand design that isn't built
                // for dark-mode adaptation, so lock it to its intended appearance.
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    // Notification permission can be revoked in iOS Settings while Soma is
                    // backgrounded, so the reminders toggle is re-checked on every activation.
                    guard phase == .active else { return }
                    Task { await NotificationManager.shared.refreshPermissionState() }
                    Task { await SomaSpotlightIndexer.sync(context: sharedModelContainer.mainContext) }
                }
                .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                    // Any log, edit or delete ends here. The sync is idempotent, and the short pause
                    // lets one log's several writes settle into a single index update.
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await SomaSpotlightIndexer.sync(context: sharedModelContainer.mainContext)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
