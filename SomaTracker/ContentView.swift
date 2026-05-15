//
//  ContentView.swift
//  SomaTracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var appRouter = AppRouter()
    @State private var tabRouter = TabRouter()

    var body: some View {
        if !appRouter.hasCompletedOnboarding {
            Text("Onboarding")
        } else {
            mainTabView
        }
    }

    // MARK: - Main tab view

    private var mainTabView: some View {
        TabView(selection: $tabRouter.selectedTab) {
            Text("Home")
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)
                .toolbar(.hidden, for: .tabBar)
            Text("Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
                .toolbar(.hidden, for: .tabBar)
        }
        .overlay(alignment: .bottomTrailing) {
            Button(action: { appRouter.showLogSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $appRouter.showLogSheet) {
            Text("Log Sheet")
        }
        .environment(appRouter)
        .environment(tabRouter)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
