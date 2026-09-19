//
//  SomaThinkingIndicator.swift
//  SomaTracker
//
//  Soma's mark, and the only thing that moves while an engine is working: a soft pulse of the mark
//  itself. No rings. Outlines around a filled circle read as decoration, and they used to sit on screen
//  the whole time the chat was open, which is what the owner pointed at.
//
//  At rest the mark is drawn at full strength. It used to idle at 72% opacity and 94% scale, which read
//  as a disabled control in the header rather than as Soma's mark.
//

import SwiftUI

struct SomaThinkingIndicator: View {
    /// True while an engine is working. At rest the mark is completely still, so nothing on this screen
    /// looks like it is waiting when it is not.
    var isAnimating = false
    var size: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .scaleEffect(pulse ? 1.06 : 1)
        .animation(pulse ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) : .default, value: pulse)
        .onAppear { pulse = isAnimating && !reduceMotion }
        .onChange(of: isAnimating) { _, animating in
            // Reduce Motion is a promise, so the pulse is dropped entirely rather than slowed.
            pulse = animating && !reduceMotion
        }
        .onChange(of: reduceMotion) { _, _ in
            pulse = isAnimating && !reduceMotion
        }
        // The label next to the mark says what is happening, so the mark itself is decoration.
        .accessibilityHidden(true)
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
