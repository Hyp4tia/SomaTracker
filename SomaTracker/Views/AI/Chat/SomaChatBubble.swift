//
//  SomaChatBubble.swift
//  SomaTracker
//
//  One message, drawn. Soma's replies carry the same numbers, the same palette and the same card
//  treatment as the journal, so the chat never reads as a second opinion about the user's own log.
//

import SwiftUI

struct SomaChatBubble: View {
    let message: SomaChatMessage
    /// Taps "Log this" on an answered question. Writing it is the user's decision, not the assistant's.
    var onLog: (() -> Void)?

    @State private var player = AudioPlaybackService()

    /// Wide enough for two metric chips side by side at the largest text size Soma uses.
    private let cardWidth: CGFloat = 330
    /// The same gutter the thinking row uses, so both sides of the conversation line up.
    private let gutter: CGFloat = 46

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.author == .user { Spacer(minLength: gutter) }

            bubble
                .frame(
                    maxWidth: message.kind == .analysis || message.kind == .answer ? cardWidth : 300,
                    alignment: message.author == .user ? .trailing : .leading
                )

            if message.author == .soma { Spacer(minLength: gutter) }
        }
        // Playback belongs to the conversation, not to the view: scrolling away or closing the chat has
        // to silence it.
        .onDisappear { player.stop() }
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.kind {
        case .user: userBubble
        case .analysis: analysisCard
        case .answer: answerCard
        case .notice: noticeCard
        }
    }

    // MARK: - User

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if !message.photos.isEmpty { photoStrip }

            if message.voiceRelativePath != nil { voiceRow }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(SomaColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var photoStrip: some View {
        HStack(spacing: 6) {
            ForEach(Array(message.photos.prefix(3).enumerated()), id: \.offset) { index, data in
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel("Meal photo \(index + 1) of \(message.photos.count)")
                }
            }

            // Up to five photos can be sent, and three are drawn: the rest are counted rather than
            // silently dropped.
            if message.photos.count > 3 {
                Text("+\(message.photos.count - 3)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SomaColors.navy)
                    .frame(width: 40, height: 76)
                    .background(SomaColors.navy.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("\(message.photos.count - 3) more photos")
            }
        }
    }

    /// A voice memo the user can replay without leaving the conversation. The bars are the recording
    /// itself, the same view the meal detail uses, so the memo is evidence rather than decoration.
    private var voiceRow: some View {
        HStack(spacing: 10) {
            Button {
                playVoice()
            } label: {
                ZStack {
                    Circle()
                        .fill(SomaColors.navy)
                        .frame(width: 44, height: 44)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause voice memo" : "Play voice memo")

            VStack(alignment: .leading, spacing: 4) {
                AudioWaveformView(samples: message.voiceWaveformSamples, progress: player.progress, isLiveRecording: false)
                    .frame(width: 120, height: 26)

                Text(durationLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Soma

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)

                if !message.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                        Text(message.location)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(.secondaryLabel))
                }
            }

            metrics

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !message.sources.isEmpty { sourceLinks }

            if message.isLogged {
                Label("Added to your journal", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SomaColors.emerald)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onLog?()
                } label: {
                    Label("Log this", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(SomaColors.navy)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                // HIG: 44pt minimum, which a capsule of this size does not reach on its own.
                .contentShape(Capsule())
                .frame(minHeight: 44)
                .accessibilityLabel("Log this meal to the journal")
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
        .animation(.snappy(duration: 0.25), value: message.isLogged)
    }

    /// Two rows of two, so a four-digit calorie count always has room. The single line this replaced
    /// truncated the numbers themselves, which is the one thing a food card cannot do.
    @ViewBuilder
    private var metrics: some View {
        if message.waterML > 0 {
            chip(icon: "drop.fill", color: SomaColors.aqua, value: message.waterML.formatted(), unit: "ml")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    chip(icon: "flame.fill", color: SomaColors.coral, value: message.calories.formatted(), unit: "kcal")
                    chip(icon: "bolt.fill", color: SomaColors.iris, value: "\(Int(message.proteinG.rounded()))", unit: "g protein")
                }
                HStack(spacing: 8) {
                    chip(icon: "circle.hexagongrid.fill", color: SomaColors.amber, value: "\(Int(message.carbsG.rounded()))", unit: "g carbs")
                    chip(icon: "drop.degreesign.fill", color: SomaColors.teal, value: "\(Int(message.fatG.rounded()))", unit: "g fat")
                }
            }
        }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)

            if !message.sources.isEmpty { sourceLinks }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
    }

    /// Where a searched answer came from. Tappable, and each row is a full-width 44pt target rather than
    /// a line of 9pt text.
    private var sourceLinks: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(message.sources.prefix(3)) { source in
                Link(destination: source.url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .bold))
                        Text(source.title)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundStyle(SomaColors.navy.opacity(0.75))
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    private var noticeCard: some View {
        HStack(spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SomaColors.streakOrange)

            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SomaColors.streakOrange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
    }

    private func chip(icon: String, color: Color, value: String, unit: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.label))
                .lineLimit(1)

            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(unit) \(value)")
    }

    // MARK: - Voice playback

    private func playVoice() {
        guard let path = message.voiceRelativePath else { return }
        if player.duration <= 0 {
            player.loadAudio(relativePath: path)
            player.play()
        } else {
            player.togglePlayback()
        }
    }

    private var durationLabel: String {
        let remaining = message.voiceDuration - (player.duration * player.progress)
        let seconds = max(0, Int(remaining.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
