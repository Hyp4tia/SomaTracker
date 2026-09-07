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
                .environment(appRouter)
                .environment(tabRouter)
        }
        .environment(appRouter)
        .environment(tabRouter)
        .onReceive(NotificationCenter.default.publisher(for: .somaTriggerQuickAction)) { _ in
            withAnimation(.snappy(duration: 0.2)) {
                tabRouter.selectedTab = .ai
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onAppear {
            if AppNavigationState.shared.pendingQuickAction != nil {
                tabRouter.selectedTab = .ai
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "somatracker" || url.scheme?.lowercased() == "soma" else { return }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if host == "camera" || path.contains("camera") {
            tabRouter.selectedTab = .ai
            AppNavigationState.shared.triggerAction(.camera)
        } else if host == "voice" || path.contains("voice") {
            tabRouter.selectedTab = .ai
            AppNavigationState.shared.triggerAction(.voice)
        } else if host == "ai" || path.contains("ai") {
            tabRouter.selectedTab = .ai
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
