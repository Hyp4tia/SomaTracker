//
//  SomaThinkingIndicator.swift
//  SomaTracker
//
//  Soma's mark, and the only thing that moves while an engine is working: a soft pulse of the mark
//  itself. No rings. Outlines around a filled circle read as decoration, and they used to sit on screen
//  the whole time the chat was open, which is what the owner pointed at.
//

import SwiftUI

struct SomaThinkingIndicator: View {
    /// True while an engine is working. At rest the mark is completely still, so nothing on this screen
    /// looks like it is waiting when it is not.
    var isAnimating = false
    var size: CGFloat = 44

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(SomaColors.navy)
                .frame(width: size, height: size)

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
        }
        .scaleEffect(pulse ? 1.06 : 0.94)
        .opacity(pulse ? 1 : 0.72)
        .animation(
            isAnimating ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) : .default,
            value: pulse
        )
        .onAppear { pulse = isAnimating }
        .onChange(of: isAnimating) { _, animating in
            pulse = animating
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        SomaThinkingIndicator(size: 30)
        SomaThinkingIndicator(isAnimating: true)
    }
    .padding(40)
    .background(Color(.systemGroupedBackground))
}
