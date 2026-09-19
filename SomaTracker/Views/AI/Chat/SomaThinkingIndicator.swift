//
//  SomaThinkingIndicator.swift
//  SomaTracker
//
//  The ripple from the reference the owner sent, rebuilt in SwiftUI: rings that expand and fade out of
//  the Soma mark while an engine is working. One animated value drives every ring, which is what keeps
//  it smooth and cheap on a phone.
//

import SwiftUI

struct SomaThinkingIndicator: View {
    /// 0 at the start of a ripple cycle, 1 when the outermost ring has faded out.
    @State private var phase: Double = 0

    private let ringCount = 3

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { index in
                let offset = Double(index) / Double(ringCount)
                let progress = (phase + offset).truncatingRemainder(dividingBy: 1)

                Circle()
                    .stroke(SomaColors.navy.opacity(0.30), lineWidth: 1.5)
                    .scaleEffect(0.55 + progress * 0.75)
                    .opacity(1 - progress)
            }

            Circle()
                .fill(SomaColors.navy)
                .frame(width: 22, height: 22)

            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 44)
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

#Preview {
    SomaThinkingIndicator()
        .padding(40)
        .background(Color(.systemGroupedBackground))
}
