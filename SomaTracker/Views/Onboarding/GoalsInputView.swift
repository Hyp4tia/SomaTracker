import SwiftData
import SwiftUI

struct GoalsInputView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @Binding var draft: OnboardingDraft

    var body: some View {
        ZStack {
            SomaColors.navy
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            VStack(spacing: 0) {
                OnboardingProgressDots(step: 3)
                    .padding(.top, 116)

                OnboardingIcon(systemName: "target")
                    .padding(.top, 40)

                Text("Set your goals")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text("You can always change these later in\nSettings.")
                    .font(SomaTypography.body)
                    .foregroundStyle(SomaColors.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 8)

                VStack(spacing: 20) {
                    OnboardingField(title: "Daily Calories (kcal)", text: $draft.dailyCalorieGoal, keyboardType: .numberPad)
                    OnboardingField(title: "Daily Water (ml)", text: $draft.dailyWaterGoalML, keyboardType: .numberPad)
                    OnboardingField(title: "Daily Protein (g)", text: $draft.dailyProteinGoalG, keyboardType: .numberPad)
                }
                .padding(.top, 40)

                Spacer()

                Button(action: saveProfile) {
                    OnboardingContinueLabel(title: "Continue ->")
                }
                .buttonStyle(.plain)

                Button(action: saveProfile) {
                    Text("Skip for now")
                        .font(SomaTypography.body.weight(.semibold))
                        .foregroundStyle(SomaColors.white.opacity(0.48))
                }
                .buttonStyle(.plain)
                .padding(.top, 28)
                .padding(.bottom, 42)
            }
            .padding(.horizontal, 24)
        }
        .dismissKeyboardOnInteraction()
        .navigationBarBackButtonHidden()
    }

    private func saveProfile() {
        let profile = profiles.first ?? UserProfile(
            name: draft.resolvedName,
            age: draft.resolvedAge,
            gender: draft.gender,
            weightKG: draft.resolvedWeightKG,
            heightCM: draft.resolvedHeightCM,
            activityLevel: draft.defaultActivityLevel
        )

        profile.name = draft.resolvedName
        profile.age = draft.resolvedAge
        profile.gender = draft.gender
        profile.weightKG = draft.resolvedWeightKG
        profile.heightCM = draft.resolvedHeightCM
        profile.activityLevel = draft.defaultActivityLevel
        profile.dailyCalorieGoal = draft.resolvedDailyCalorieGoal
        profile.dailyWaterGoalML = draft.resolvedDailyWaterGoalML
        profile.dailyProteinGoalG = draft.resolvedDailyProteinGoalG
        profile.hasCompletedOnboarding = true

        if profiles.first == nil {
            modelContext.insert(profile)
        }

        try? modelContext.save()
        appRouter.hasCompletedOnboarding = true
    }
}

#Preview {
    @Previewable @State var draft = OnboardingDraft()

    NavigationStack {
        GoalsInputView(draft: $draft)
            .environment(AppRouter())
            .modelContainer(PreviewData.container)
    }
}
