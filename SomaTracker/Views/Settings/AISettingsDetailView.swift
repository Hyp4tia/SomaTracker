//
//  AISettingsDetailView.swift
//  SomaTracker
//
//  Soma AI and Siri integration overview.
//

import SwiftUI

struct AISettingsDetailView: View {
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @AppStorage(OnDeviceAISettings.defaultsKey) private var onDeviceAI = true
    @AppStorage(AIFactCheckService.defaultsKey) private var factCheck = true

    var body: some View {
        List {
            // Section 1: Engine Status & Pro Access
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
                                Text("Soma Intelligence")
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

                            Text(subscriptionManager.isPro ? "Active · Unlimited vision & voice scans" : "Upgrade to Pro for unlimited AI scans")
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
                Text("STATUS")
            }

            // Section 2: Which engine answers
            Section {
                Toggle(isOn: $onDeviceAI) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SomaColors.iris)
                                .frame(width: 32, height: 32)

                            Image(systemName: "cpu")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("On-device analysis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text(engineStatusText)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.vertical, 3)
                }
                .disabled(!OnDeviceAIService.isReady)

                Toggle(isOn: $factCheck) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SomaColors.emerald)
                                .frame(width: 32, height: 32)

                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fact-check with the cloud")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text(factCheckStatusText)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.vertical, 3)
                }
                .disabled(!OnDeviceAIService.isReady || !onDeviceAI)
            } header: {
                Text("ANALYSIS ENGINE")
            } footer: {
                Text("Meals you describe by voice or text are estimated on this iPhone, so the answer is instant and your words stay on it. The cloud model is asked when the on-device answer needs more muscle, when it takes too long, and for every photo.")
            }

            // Section 3: Siri & Action Button Shortcuts
            Section {
                featureRow(
                    icon: "mic.fill",
                    iconColor: SomaColors.navy,
                    title: "Voice Logging with Siri",
                    subtitle: "Say \"Hey Siri, log a chicken salad in Soma\""
                )

                featureRow(
                    icon: "drop.fill",
                    iconColor: SomaColors.aqua,
                    title: "Quick Hydration",
                    subtitle: "Say \"Hey Siri, log 250 water with Soma\""
                )

                featureRow(
                    icon: "button.vertical.left.press.fill",
                    iconColor: Color(hex: "007AFF"),
                    title: "Action Button & Lock Screen",
                    subtitle: "Add Soma Camera or Voice shortcuts in iOS Settings"
                )
            } header: {
                Text("SIRI & SHORTCUTS")
            } footer: {
                Text("Works directly through Siri, Shortcuts, and the iPhone Action Button.")
            }

            // Section 3: Privacy & Security
            Section {
                featureRow(
                    icon: "lock.shield.fill",
                    iconColor: SomaColors.emerald,
                    title: "Private AI Analysis",
                    subtitle: "Meal scans are analyzed in secure, stateless sessions and never linked to your identity"
                )

                featureRow(
                    icon: "internaldrive.fill",
                    iconColor: SomaColors.iris,
                    title: "On-Device Storage",
                    subtitle: "Your meal journal, voice audio, and personal targets stay on your iPhone"
                )
            } header: {
                Text("PRIVACY")
            } footer: {
                Text("Soma does not require an account. AI nutritional estimates are processed securely and statelessly.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("AI & Siri")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBarWithCoordinator()
        .sheet(isPresented: $showPaywall) {
            SomaPaywallView()
        }
    }

    private var factCheckStatusText: String {
        guard onDeviceAI else { return "Paused while on-device analysis is off" }
        return factCheck
            ? "Every on-device answer is verified after it is logged"
            : "Off, on-device answers are final"
    }

    private var engineStatusText: String {
        switch OnDeviceAIService.status {
        case .ready:
            return onDeviceAI ? "First choice, cloud as the second opinion" : "Off, everything goes to the cloud"
        case .needsNewerSystem:
            return "Needs iOS 26 or later"
        case .languageUnsupported(let reason):
            return reason
        case .unavailable(let reason):
            return reason
        }
    }

    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.label))

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    NavigationStack {
        AISettingsDetailView()
    }
}
