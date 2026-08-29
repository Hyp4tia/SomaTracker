import SwiftUI

struct NameInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: OnboardingDraft

    var body: some View {
        ZStack {
            SomaColors.navy
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }

            VStack(spacing: 0) {
                OnboardingTopBar(step: 1) {
                    dismiss()
                }
                .padding(.top, 56)

                Spacer(minLength: 16)

                OnboardingIcon(systemName: "person.fill")

                Text("What's your name?")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(SomaColors.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("We'll personalize your experience based on who you are.")
                    .font(SomaTypography.body)
                    .foregroundStyle(SomaColors.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)

                OnboardingField(title: "Full Name", text: $draft.name)
                    .padding(.top, 40)

                Spacer(minLength: 24)

                NavigationLink {
                    BodyStatsView(draft: $draft)
                } label: {
                    OnboardingContinueLabel()
                }

                OnboardingSkipLink(destination: BodyStatsView(draft: $draft))
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
        NameInputView(draft: $draft)
    }
}
