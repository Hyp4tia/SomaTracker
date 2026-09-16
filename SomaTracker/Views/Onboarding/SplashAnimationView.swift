import SwiftUI
import DotLottie

/// Lottie animation shown on the splash / first-launch screen.
struct SplashAnimationView: View {
    var body: some View {
        // `DotLottieAnimation.view()` is declared twice in DotLottie (once returning the
        // SwiftUI `DotLottieView`, once returning the UIKit `DotLottieAnimationView` under
        // `#if os(iOS)`), so the result type has to be stated explicitly to disambiguate.
        let animation: DotLottieView = DotLottieAnimation(
            fileName: "splash_animation",
            config: AnimationConfig(autoplay: true, loop: true)
        ).view()
        animation
    }
}

#Preview {
    SplashAnimationView()
        .frame(width: 320, height: 320)
        .background(SomaColors.navy)
}
