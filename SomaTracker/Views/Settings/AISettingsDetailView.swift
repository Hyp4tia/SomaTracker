//
//  AISettingsDetailView.swift
//  SomaTracker
//
//  Soma Pro and Siri AI overview screen (no manual API key entry required).
//

import SwiftUI

struct AISettingsDetailView: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    var body: some View {
        List {
            // Section 1: Pro Status
            Section {
                Button {
                    if !subscriptionManager.isPro {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(SomaColors.navy)
                                .frame(width: 44, height: 44)

                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Soma AI Intelligence")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(.label))

                                if subscriptionManager.isPro {
                                    Text("PRO")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(SomaColors.emerald)
                                        .clipShape(Capsule())
                                } else {
                                    Text(subscriptionManager.remainingFreeScans > 0 ? "\(subscriptionManager.remainingFreeScans) FREE" : "UPGRADE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(SomaColors.navy)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(SomaColors.navy.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }

                            Text(subscriptionManager.isPro ? "Full unlimited Soma AI & Siri voice access" : "Tap to view Soma Pro plans & unlock unlimited scans")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        Spacer()

                        if !subscriptionManager.isPro {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("SOMA AI ENGINE")
            }

            // Section 2: Siri Voice Commands
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hands-free Siri commands:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))

                    VStack(alignment: .leading, spacing: 6) {
                        siriPhraseRow(phrase: "\"Hey Siri, log 100 water with Soma\"", detail: "Logs 100 ml water")
                        siriPhraseRow(phrase: "\"Hey Siri, log a chicken salad in Soma\"", detail: "Logs 380 kcal, 32g protein")
                        siriPhraseRow(phrase: "\"Hey Siri, log 500 calories in Soma\"", detail: "Logs 500 kcal energy")
                        siriPhraseRow(phrase: "\"Hey Siri, log 40 protein in Soma\"", detail: "Logs 40g protein")
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            } header: {
                Text("SIRI VOICE COMMANDS")
            } footer: {
                Text("Works directly with Siri on iOS without needing to open the app.")
            }

            // Section 3: iPhone Action Button & Lock Screen Shortcuts
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(hex: "007AFF"))
                                .frame(width: 36, height: 36)
                            Image(systemName: "button.vertical.left.press.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Action Button Quick Capture")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text("Press your iPhone Action Button to instantly snap a meal or record voice")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        setupStepRow(step: "1", text: "Open iPhone Settings > Action Button")
                        setupStepRow(step: "2", text: "Swipe to 'Shortcut' and tap 'Choose a Shortcut'")
                        setupStepRow(step: "3", text: "Select Soma > 'Snap Meal Photo with Soma AI' or 'Record Voice Meal with Soma AI'")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("IPHONE ACTION BUTTON")
            } footer: {
                Text("You can also add these same shortcuts to your iOS Lock Screen or Control Center.")
            }

            // Section 4: Privacy & Data Security
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(SomaColors.emerald)
                        Text("Your Health Data Stays Yours")
                            .font(.system(size: 15, weight: .semibold))
                    }

                    Text("All your meal history, daily targets, and personal metrics remain strictly on your iPhone. When using Soma AI, meal photos and descriptions are analyzed in secure, encrypted sessions solely to estimate nutrition facts—never linked to your identity and never sold or shared with advertisers.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("PRIVACY & DATA SECURITY")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Soma AI & Siri")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBarWithCoordinator()
        .sheet(isPresented: $showPaywall) {
            SomaPaywallView()
        }
    }

    private func siriPhraseRow(phrase: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phrase)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(SomaColors.navy)

            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.vertical, 2)
    }

    private func setupStepRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(SomaColors.navy)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsDetailView()
    }
}
