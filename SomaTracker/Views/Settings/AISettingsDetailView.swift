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
    /// Empty until the user picks, so an install from before this screen keeps its old behaviour.
    @AppStorage(OnDeviceAISettings.modeKey) private var storedModeRaw = ""
    @AppStorage(OnDeviceAISettings.photosOnDeviceKey) private var photosOnDevice = false
    @AppStorage(SomaChatSettings.surfaceKey) private var chatSurface = true

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

            // Section 2: Which engine answers. One choice, because the two switches this replaced
            // described the same traffic once both were on.
            Section {
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
                        Text("Analysis engine")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(.label))

                        Text(analysisMode.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.vertical, 3)

                Picker("Analysis engine", selection: analysisModeBinding) {
                    ForEach(AnalysisMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!OnDeviceAIService.isReady)

                if !OnDeviceAIService.isReady {
                    Text(engineStatusText)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                }

                if OnDeviceAIService.isReady, OnDeviceAIService.supportsImageInput, analysisMode == .localFirst {
                    Toggle(isOn: $photosOnDevice) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(SomaColors.iris)
                                    .frame(width: 32, height: 32)

                                Image(systemName: "photo.badge.checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Keep meal photos on this iPhone")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color(.label))

                                Text(photosOnDevice
                                     ? "Photos are read on-device and never uploaded. Slower, and no cloud review"
                                     : "Off, photos go to the cloud, which reads them faster and better")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                Text("ANALYSIS ENGINE")
            } footer: {
                Text("On-device first answers instantly on this iPhone and the cloud model checks the numbers after they are logged. Cloud first sends every log to the cloud and nothing runs locally.")
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

            // Section 3: the conversation surface, with the plain bar as the fallback
            Section {
                Toggle(isOn: $chatSurface) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(SomaColors.navy)
                                .frame(width: 32, height: 32)

                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conversational Soma")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(.label))

                            Text(chatSurface
                                 ? "The log bar expands into a full-screen chat"
                                 : "Off, the AI tab uses the plain log bar")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("CONVERSATION")
            } footer: {
                Text("Tap the bar above the journal to talk to Soma: type, send photos, or record a voice log. Switching this off restores the plain bar.")
            }

            // Section 4: the phrases Soma actually registers, so this screen cannot promise something
            // Siri will not answer. They mirror SomaShortcuts.
            Section {
                ForEach(Self.siriPhrases, id: \.self) { phrase in
                    HStack(spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SomaColors.navy.opacity(0.4))
                            .frame(width: 16)

                        Text(phrase)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(.label))
                    }
                    .padding(.vertical, 1)
                }
            } header: {
                Text("TRY SAYING")
            } footer: {
                Text("Ask Siri out loud or type it, or run any of them from the Shortcuts app.")
            }

            // Section 4: Privacy & Security
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

    private static let siriPhrases = [
        "Hey Siri, log 250 water with Soma",
        "Hey Siri, log a chicken shawarma in Soma",
        "Hey Siri, scan food with Soma",
        "Hey Siri, how many calories did I eat in Soma",
        "Hey Siri, how much protein do I have left in Soma",
        "Hey Siri, how is my day in Soma",
        "Hey Siri, what's my streak in Soma"
    ]

    private var analysisMode: AnalysisMode {
        AnalysisMode(rawValue: storedModeRaw) ?? OnDeviceAISettings.mode
    }

    private var analysisModeBinding: Binding<AnalysisMode> {
        Binding(get: { analysisMode }, set: { storedModeRaw = $0.rawValue })
    }

    /// Shown under the picker only when this iPhone cannot run the local model, so the disabled
    /// option is explained rather than silent.
    private var engineStatusText: String {
        switch OnDeviceAIService.status {
        case .ready:
            return analysisMode.detail
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
