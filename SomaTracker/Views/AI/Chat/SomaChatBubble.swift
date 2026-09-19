//
//  SomaChatBubble.swift
//  SomaTracker
//
//  One message, drawn as a conversation rather than as a form. Bubbles, not cards: the user's in navy,
//  Soma's in the grouped grey, with the corner nearest the speaker tucked in.
//
//  A meal keeps Soma's own numbers, and a logged one says so in green rather than keeping the button.
//

import SwiftUI

struct SomaChatBubble: View {
    let message: SomaChatMessage
    /// Taps "Log this" on an answered question. Writing it is the user's decision, not the assistant's.
    var onLog: (() -> Void)?
    /// A line under the text inside the bubble: the thinking row's progress bar, for instance.
    var accessory: AnyView?

    @State private var player = AudioPlaybackService()

    /// Where the bubble stops, so the other side is never crowded.
    private var maxWidth: CGFloat { message.author == .user ? 278 : 292 }

    var body: some View {
        VStack(alignment: message.author == .user ? .trailing : .leading, spacing: 4) {
            bubble

            // The receipt sits under the bubble, out of the conversation's way.
            if message.kind == .analysis, message.isLogged {
                Label("logged to your journal", systemImage: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SomaColors.emerald)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.author == .user ? .trailing : .leading)
        .onDisappear { player.stop() }
    }

    @ViewBuilder
    private var bubble: some View {
        switch message.kind {
        case .user: userBubble
        case .analysis: analysisBubble
        case .answer: answerBubble
        case .notice: noticeBubble
        }
    }

    // MARK: - Bubbles

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if !message.photos.isEmpty { photoStrip }

            if message.voiceRelativePath != nil { voiceBubble }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(SomaColors.navy, in: userShape)
                    .frame(maxWidth: maxWidth, alignment: .trailing)
            }
        }
    }

    private var analysisBubble: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(message.title)
                .font(.system(size: 15, weight: .bold))
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

            // The numbers the app is actually built around, tabular so they line up between messages.
            if message.waterML > 0 {
                numbers([("drop.fill", SomaColors.aqua, "\(message.waterML.formatted()) ml")])
            } else if message.calories > 0 {
                numbers([
                    ("flame.fill", SomaColors.coral, "\(message.calories.formatted()) kcal"),
                    ("bolt.fill", SomaColors.iris, "\(Int(message.proteinG.rounded())) g protein"),
                ])
            }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !message.sources.isEmpty { sourceLinks }

            if !message.isLogged {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onLog?()
                } label: {
                    Label("Log this", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(SomaColors.navy, in: Capsule())
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .frame(minHeight: 44)
                .accessibilityLabel("Log this meal to the journal")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(Color(.systemGray5), in: somaShape)
        .animation(.snappy(duration: 0.25), value: message.isLogged)
    }

    private var answerBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)

            if !message.sources.isEmpty { sourceLinks }

            if let accessory { accessory }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(Color(.systemGray5), in: somaShape)
    }

    private var noticeBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SomaColors.streakOrange)

            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(Color(.label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(SomaColors.streakOrange.opacity(0.12), in: somaShape)
    }

    /// The corner nearest the speaker is tucked in, which is what makes a column of these read as a
    /// conversation rather than as a stack of panels.
    private var userShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 19,
            bottomLeadingRadius: 19,
            bottomTrailingRadius: 6,
            topTrailingRadius: 19,
            style: .continuous
        )
    }

    private var somaShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 19,
            bottomLeadingRadius: 6,
            bottomTrailingRadius: 19,
            topTrailingRadius: 19,
            style: .continuous
        )
    }

    private func numbers(_ values: [(String, Color, String)]) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                HStack(spacing: 4) {
                    Image(systemName: value.0)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(value.1)
                    Text(value.2)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(.label))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(values.map(\.2).joined(separator: ", "))
    }

    // MARK: - Attachments

    private var photoStrip: some View {
        HStack(spacing: 5) {
            ForEach(Array(message.photos.prefix(3).enumerated()), id: \.offset) { index, data in
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                        .accessibilityLabel("Meal photo \(index + 1) of \(message.photos.count)")
                }
            }

            // Up to five can be sent and three are drawn, so the rest are counted rather than dropped.
            if message.photos.count > 3 {
                Text("+\(message.photos.count - 3)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 108, height: 108)
                    .background(SomaColors.navy.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 2)
                    )
                    .accessibilityLabel("\(message.photos.count - 3) more photos")
            }
        }
    }

    /// The memo rides inside the bubble, so a voice message and a typed one look like the same act.
    private var voiceBubble: some View {
        HStack(spacing: 9) {
            Button {
                playVoice()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 34, height: 34)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SomaColors.navy)
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause voice memo" : "Play voice memo")

            VStack(alignment: .leading, spacing: 5) {
                AudioWaveformView(
                    samples: message.voiceWaveformSamples,
                    progress: player.progress,
                    isLiveRecording: false
                )
                .frame(width: 116, height: 22)

                Text(durationLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(SomaColors.navy, in: userShape)
        .accessibilityElement(children: .combine)
    }

    /// Where a searched answer came from. Legible, and each row is a full 44pt target.
    private var sourceLinks: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(message.sources.prefix(3)) { source in
                Link(destination: source.url) {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10, weight: .bold))
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
