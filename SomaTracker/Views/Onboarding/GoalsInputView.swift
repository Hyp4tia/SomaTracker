import SwiftData
import SwiftUI

struct GoalsInputView: View {
    @Environment(\.dismiss) private var dismiss
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
                OnboardingTopBar(step: 3) {
                    dismiss()
                }
                .padding(.top, 56)

                Spacer(minLength: 12)

                OnboardingIcon(systemName: "target")

                Text("Set your goals")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("You can always change these later in Settings.")
                    .font(SomaTypography.body)
                    .foregroundStyle(SomaColors.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                VStack(spacing: 16) {
                    OnboardingField(title: "Daily Calories (kcal)", text: $draft.dailyCalorieGoal, keyboardType: .numberPad)
                    OnboardingField(title: "Daily Water (ml)", text: $draft.dailyWaterGoalML, keyboardType: .numberPad)
                    OnboardingField(title: "Daily Protein (g)", text: $draft.dailyProteinGoalG, keyboardType: .numberPad)
                }
                .padding(.top, 28)

                Spacer(minLength: 24)

                Button(action: saveProfile) {
                    OnboardingContinueLabel()
                }
                .buttonStyle(.plain)

                Button(action: saveProfile) {
                    Text("Skip for now")
                        .font(SomaTypography.body.weight(.semibold))
                        .foregroundStyle(SomaColors.white.opacity(0.48))
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
            .padding(.horizontal, 28)
        }
        .dismissKeyboardOnInteraction()
        .navigationBarBackButtonHidden()
        .toolbarBackground(SomaColors.navy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(SomaColors.navy.ignoresSafeArea())
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
