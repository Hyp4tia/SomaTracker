import SwiftData
import SwiftUI

struct SplashView: View {
    @State private var draft = OnboardingDraft()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                SomaColors.navy
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 100)

                    Image("soma-icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)

                    Text("Track what\nmatters.")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(SomaColors.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 58)

                    Text("Calories, water, protein, steps. Four\nhabits. One simple tracker.")
                        .font(SomaTypography.body)
                        .foregroundStyle(SomaColors.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.top, 24)

                    Spacer()
                        .frame(height: 430)
                }

                VStack(spacing: 28) {
                    NavigationLink {
                        NameInputView(draft: $draft)
                    } label: {
                        Text("Get Started")
                            .font(SomaTypography.body.weight(.bold))
                            .foregroundStyle(SomaColors.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(SomaColors.navy)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 116)

                    Image("splash-illustration")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 230)
                        .frame(maxHeight: 210)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 455)
                .background(SomaColors.white)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationBarBackButtonHidden()
        }
    }
}

#Preview {
    SplashView()
        .modelContainer(PreviewData.container)
}
