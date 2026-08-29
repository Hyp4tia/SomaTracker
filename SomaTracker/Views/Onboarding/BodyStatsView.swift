import SwiftUI

struct BodyStatsView: View {
    @Environment(\.dismiss) private var dismiss
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
                OnboardingTopBar(step: 2) {
                    dismiss()
                }
                .padding(.top, 56)

                Spacer(minLength: 12)

                OnboardingIcon(systemName: "figure.arms.open")

                Text("Your body stats")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Used to calculate your daily calorie and protein targets.")
                    .font(SomaTypography.body)
                    .foregroundStyle(SomaColors.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                LazyVGrid(columns: columns, spacing: 16) {
                    OnboardingField(title: "Age", text: $draft.age, keyboardType: .numberPad)
                    OnboardingPickerField(title: "Gender", selection: $draft.gender)
                    OnboardingField(title: "Weight (kg)", text: $draft.weightKG, keyboardType: .decimalPad)
                    OnboardingField(title: "Height (cm)", text: $draft.heightCM, keyboardType: .decimalPad)
                }
                .padding(.top, 32)

                Spacer(minLength: 24)

                NavigationLink {
                    GoalsInputView(draft: $draft)
                } label: {
                    OnboardingContinueLabel()
                }

                OnboardingSkipLink(destination: GoalsInputView(draft: $draft))
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
}

#Preview {
    @Previewable @State var draft = OnboardingDraft()

    NavigationStack {
        BodyStatsView(draft: $draft)
    }
}
