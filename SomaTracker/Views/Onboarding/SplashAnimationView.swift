import SwiftUI
import DotLottie

/// Lottie animation shown on the splash / first-launch screen.
struct SplashAnimationView: View {
    var body: some View {
        DotLottieAnimation(
            fileName: "splash_animation",
            config: AnimationConfig(autoplay: true, loop: true)
        ).view()
    }
}

#Preview {
    SplashAnimationView()
        .frame(width: 320, height: 320)
        .background(SomaColors.navy)
}
