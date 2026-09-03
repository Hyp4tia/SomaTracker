//
//  ContentView.swift
//  SomaTracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var appRouter = AppRouter()
    @State private var tabRouter = TabRouter()
    @State private var healthKitManager = HealthKitManager()

    var body: some View {
        if !appRouter.hasCompletedOnboarding {
            SplashView()
                .environment(appRouter)
        } else {
            mainTabView
        }
    }

    // MARK: - Main tab view

    private var mainTabView: some View {
        TabView(selection: $tabRouter.selectedTab) {
            HomeView(healthKitManager: healthKitManager)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)

            NavigationStack {
                AIView()
            }
            .tabItem { Label("AI", systemImage: "sparkles") }
            .tag(Tab.ai)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .sheet(isPresented: $appRouter.showLogSheet) {
            LogSheetView()
                .preferredColorScheme(.light)
                .presentationDetents([.fraction(0.78)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(.systemBackground))
        }
        .environment(appRouter)
        .environment(tabRouter)
    }

}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
