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

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.author == .user { Spacer(minLength: 40) }

            bubble
                .frame(
                    maxWidth: message.kind == .analysis || message.kind == .answer ? cardWidth : 300,
                    alignment: message.author == .user ? .trailing : .leading
                )

            if message.author == .soma { Spacer(minLength: 40) }
        }
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
            ForEach(Array(message.photos.prefix(3).enumerated()), id: \.offset) { _, data in
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    /// A voice memo the user can replay without leaving the conversation.
    private var voiceRow: some View {
        HStack(spacing: 10) {
            Button {
                playVoice()
            } label: {
                ZStack {
                    Circle()
                        .fill(SomaColors.navy)
                        .frame(width: 30, height: 30)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                waveform
                Text(durationLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var waveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<18, id: \.self) { index in
                Capsule()
                    .fill(SomaColors.navy.opacity(played(index) ? 0.85 : 0.22))
                    .frame(width: 3, height: barHeight(index))
            }
        }
    }

    // MARK: - Soma

    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(.label))
                    .fixedSize(horizontal: false, vertical: true)

                if !message.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
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
            } else {
                Button {
                    onLog?()
                } label: {
                    Label("Log this", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(SomaColors.navy)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
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

    /// Where a searched answer came from. Tappable, and small: it is evidence, not the answer.
    private var sourceLinks: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(message.sources.prefix(3)) { source in
                Link(destination: source.url) {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                            .font(.system(size: 9, weight: .bold))
                        Text(source.title)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(SomaColors.navy.opacity(0.7))
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
    }

    private func chip(icon: String, color: Color, value: String, unit: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)

            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func played(_ index: Int) -> Bool {
        Double(index) / 18.0 <= player.progress
    }

    /// Fixed shape so the waveform does not jump while playing; it reads as a memo, not a live meter.
    private func barHeight(_ index: Int) -> CGFloat {
        let pattern: [CGFloat] = [7, 12, 18, 9, 15, 22, 11, 17, 8, 14, 20, 10, 16, 12, 19, 9, 13, 7]
        return pattern[index % pattern.count]
    }
}
