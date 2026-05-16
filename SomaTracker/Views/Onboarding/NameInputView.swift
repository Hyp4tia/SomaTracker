import SwiftUI

struct NameInputView: View {
    @Binding var draft: OnboardingDraft

    var body: some View {
        ZStack {
            SomaColors.navy
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingProgressDots(step: 1)
                    .padding(.top, 116)

                OnboardingIcon(systemName: "person")
                    .padding(.top, 40)

                Text("What's your name?")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                Text("We'll personalize your\nexperience based on who you\nare.")
                    .font(SomaTypography.body)
                    .foregroundStyle(SomaColors.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 12)

                OnboardingField(title: "Full Name", text: $draft.name)
                    .padding(.top, 76)

                Spacer()

                NavigationLink {
                    BodyStatsView(draft: $draft)
                } label: {
                    OnboardingContinueLabel(title: "Continue ->")
                }

                OnboardingSkipLink(destination: BodyStatsView(draft: $draft))
                    .padding(.top, 28)
                    .padding(.bottom, 42)
            }
            .padding(.horizontal, 40)
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    @Previewable @State var draft = OnboardingDraft()

    NavigationStack {
        NameInputView(draft: $draft)
    }
}
