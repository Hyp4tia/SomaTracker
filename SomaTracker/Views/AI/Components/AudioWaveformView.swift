//
//  AudioWaveformView.swift
//  SomaTracker
//
//  Renders interactive audio waveform bars matching the user's mockup,
//  with live recording animation and scrub gesture.
//

import SwiftUI

struct AudioWaveformView: View {
    let samples: [Float]
    let progress: Double // 0.0 to 1.0
    var onSeek: ((Double) -> Void)? = nil
    var isLiveRecording: Bool = false
    var activeColor: Color = SomaColors.navy

    // Resting aesthetic audio curve when not recording and no samples exist
    private static let restingPattern: [Float] = [
        0.18, 0.35, 0.55, 0.40, 0.70, 0.50, 0.30, 0.60, 0.85, 0.65,
        0.35, 0.55, 0.30, 0.50, 0.70, 0.90, 0.60, 0.40, 0.75, 0.50,
        0.30, 0.60, 0.40, 0.65, 0.45, 0.30, 0.55, 0.35, 0.20, 0.35,
        0.25, 0.18
    ]

    private var normalizedSamples: [Float] {
        if !samples.isEmpty {
            return samples
        }
        return Self.restingPattern
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let barCount = normalizedSamples.count
            let spacing: CGFloat = 2.5
            let totalSpacing = spacing * CGFloat(max(1, barCount - 1))
            let barWidth = max(2.0, (totalWidth - totalSpacing) / CGFloat(barCount))
            let maxHeight = geometry.size.height

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let barHeight = max(4.0, maxHeight * CGFloat(normalizedSamples[index]))
                    let barProgress = Double(index) / Double(max(1, barCount - 1))
                    let isActive = isLiveRecording || (barProgress <= progress)

                    Capsule()
                        .fill(isActive ? (isLiveRecording ? Color.red : activeColor) : Color(.systemGray4))
                        .frame(width: barWidth, height: barHeight)
                        .animation(.easeOut(duration: 0.08), value: normalizedSamples[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isLiveRecording else { return }
                        let percentage = max(0.0, min(1.0, value.location.x / totalWidth))
                        onSeek?(percentage)
                    }
            )
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        AudioWaveformView(
            samples: [],
            progress: 0.35,
            onSeek: { _ in }
        )
        .frame(height: 28)
        .padding(.horizontal)

        AudioWaveformView(
            samples: [],
            progress: 1.0,
            isLiveRecording: true
        )
        .frame(height: 28)
        .padding(.horizontal)
    }
}
