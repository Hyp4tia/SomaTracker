import SwiftUI

struct BodyStatsView: View {
    @Binding var draft: OnboardingDraft

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ZStack {
            SomaColors.navy
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            VStack(spacing: 0) {
                OnboardingProgressDots(step: 2)
                    .padding(.top, 116)

                OnboardingIcon(systemName: "arrow.up.right")
                    .padding(.top, 40)

                Text("Your body stats")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text("Used to calculate your daily calorie and\nprotein targets.")
                    .font(SomaTypography.body)
                    .foregroundStyle(SomaColors.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 20)

                LazyVGrid(columns: columns, spacing: 18) {
                    OnboardingField(title: "Age", text: $draft.age, keyboardType: .numberPad)
                    OnboardingPickerField(title: "Gender", selection: $draft.gender)
                    OnboardingField(title: "Weight (kg)", text: $draft.weightKG, keyboardType: .decimalPad)
                    OnboardingField(title: "Height (cm)", text: $draft.heightCM, keyboardType: .decimalPad)
                }
                .padding(.top, 108)

                Spacer()

                NavigationLink {
                    GoalsInputView(draft: $draft)
                } label: {
                    OnboardingContinueLabel(title: "Continue ->")
                }

                OnboardingSkipLink(destination: GoalsInputView(draft: $draft))
                    .padding(.top, 28)
                    .padding(.bottom, 42)
            }
            .padding(.horizontal, 24)
        }
        .dismissKeyboardOnInteraction()
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    @Previewable @State var draft = OnboardingDraft()

    NavigationStack {
        BodyStatsView(draft: $draft)
    }
}
