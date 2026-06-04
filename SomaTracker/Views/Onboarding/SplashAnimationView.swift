import SwiftUI
import DotLottie

/// Lottie animation shown on the splash / first-launch screen.
struct SplashAnimationView: View {
    var body: some View {
        DotLottieAnimation(
            webURL: "https://lottie.host/bfc46bab-5bc1-4e8e-863e-dfb3e7aef185/o5aW8TWJq9.lottie",
            config: AnimationConfig(autoplay: true, loop: true)
        ).view()
    }
}

#Preview {
    SplashAnimationView()
        .frame(width: 320, height: 320)
        .background(SomaColors.navy)
}
