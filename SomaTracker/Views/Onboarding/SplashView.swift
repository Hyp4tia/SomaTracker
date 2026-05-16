import SwiftData
import SwiftUI

struct SplashView: View {
    @State private var draft = OnboardingDraft()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let totalHeight = geo.size.height
                let cardHeight = totalHeight * 0.55  // ← was 0.47

                ZStack(alignment: .bottom) {
                    SomaColors.navy
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        Spacer()

                        Image("soma-icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text("Track what\nmatters.")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundStyle(SomaColors.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 24)

                        Text("Calories, water, protein, steps.\nFour habits. One simple tracker.")
                            .font(.system(size: 16))
                            .foregroundStyle(SomaColors.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.top, 16)
                            .padding(.bottom, 28)

                        Color.clear.frame(height: cardHeight)
                    }

                    VStack(spacing: 0) {
                        Spacer().frame(height: 48)

                        NavigationLink {
                            NameInputView(draft: $draft)
                        } label: {
                            Text("Get Started")
                                .font(SomaTypography.body.weight(.bold))
                                .foregroundStyle(SomaColors.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(SomaColors.navy)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 28)

                        Spacer()

                        Image("splash-illustration")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 360)
                            .padding(.bottom, 32 + geo.safeAreaInsets.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
                    .background(SomaColors.white)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 32,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 32,
                            style: .continuous
                        )
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
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
