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
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tabRouter.selectedTab) {
                HomeView(healthKitManager: healthKitManager)
                    .tabItem { Label("Home", systemImage: "house") }
                    .tag(Tab.home)

                Text("Settings")
                    .font(SomaTypography.sectionTitle)
                    .foregroundStyle(Color(.label))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SomaColors.white)
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(Tab.settings)
            }

            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .contentShape(Circle())
                .onTapGesture {
                    appRouter.showLogSheet = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 68)
        }
        .sheet(isPresented: $appRouter.showLogSheet) {
            LogSheetView()
        }
        .environment(appRouter)
        .environment(tabRouter)
    }

}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
