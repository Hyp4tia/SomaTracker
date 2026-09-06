//
//  AISettingsDetailView.swift
//  SomaTracker
//
//  Soma Pro and Siri AI overview screen (no manual API key entry required).
//

import SwiftUI

struct AISettingsDetailView: View {
    var body: some View {
        Form {
            // Section 1: Pro Status
            Section {
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

                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SomaColors.navy)
                                .clipShape(Capsule())
                        }

                        Text("Multimodal voice, vision, and natural food recognition")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("INTELLIGENCE ENGINE")
            }

            // Section 2: Siri AI & Voice Commands
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hands-free Siri AI commands:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))

                    VStack(alignment: .leading, spacing: 6) {
                        siriPhraseRow(phrase: "\"Hey Siri, log 100 water with Soma\"", detail: "Logs 100 ml water")
                        siriPhraseRow(phrase: "\"Hey Siri, log a Big Mac in Soma\"", detail: "Logs 590 kcal, 25g protein")
                        siriPhraseRow(phrase: "\"Hey Siri, log 500 calories in Soma\"", detail: "Logs 500 kcal energy")
                        siriPhraseRow(phrase: "\"Hey Siri, log 40 protein in Soma\"", detail: "Logs 40g protein")
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            } header: {
                Text("APPLE INTELLIGENCE & SIRI")
            } footer: {
                Text("Works directly with Apple Intelligence on iOS without needing to open the app.")
            }

            // Section 3: iPhone Action Button & Lock Screen Shortcuts
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(SomaColors.navy.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "button.programmable")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(SomaColors.navy)
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
                        setupStepRow(step: "3", text: "Select Soma > 'Snap Meal Photo' or 'Record Voice Meal'")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("IPHONE ACTION BUTTON")
            } footer: {
                Text("You can also add these same shortcuts to your iOS Lock Screen or Control Center.")
            }

            // Section 3: Privacy & Security Guarantee
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(SomaColors.emerald)
                        Text("100% On-Device & Private")
                            .font(.system(size: 15, weight: .semibold))
                    }

                    Text("Voice notes and transcription run locally on your device via Apple Speech Framework. Your health and dietary data remain strictly on your iPhone.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(.secondaryLabel))
                }
                .padding(.vertical, 4)
            } header: {
                Text("PRIVACY & SECURITY")
            }
        }
        .navigationTitle("AI & Siri")
        .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsDetailView()
    }
}
