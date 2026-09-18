//
//  ReminderOptInView.swift
//  SomaTracker
//
//  First-run reminder opt-in, shown once after onboarding completes. Explaining the value
//  before iOS shows its own permission dialog lifts opt-in and avoids a cold ask mid-log.
//

import SwiftUI

struct ReminderOptInView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            SomaColors.navy.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                OnboardingIcon(systemName: "bell.badge.fill")

                VStack(spacing: 10) {
                    Text("Stay on track")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(SomaColors.white)

                    Text("Two gentle reminders a day: one in the morning to log your first meal, one at night to catch anything you missed. You can change the times or switch them off any time in Settings.")
                        .font(SomaTypography.body)
                        .foregroundStyle(SomaColors.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.top, 22)
                .padding(.horizontal, 28)

                Spacer(minLength: 20)

                Button {
                    Task { await enableReminders() }
                } label: {
                    OnboardingContinueLabel(
                        title: isRequesting ? "Enabling..." : "Turn on reminders",
                        showArrow: false
                    )
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .disabled(isRequesting)
                .padding(.horizontal, 24)

                Button("Not now") { dismiss() }
                    .font(SomaTypography.body.weight(.semibold))
                    .foregroundStyle(SomaColors.white.opacity(0.48))
                    .padding(.top, 16)
                    .padding(.bottom, 26)
            }
        }
        .presentationBackground(SomaColors.navy)
    }

    private func enableReminders() async {
        guard !isRequesting else { return }
        isRequesting = true
        // The sheet closes either way: a refusal is handled by Settings pointing at iOS Settings.
        _ = await NotificationManager.shared.enableRemindersFromPrompt()
        isRequesting = false
        dismiss()
    }
}

#Preview {
    ReminderOptInView()
}
