//
//  SomaChatSurface.swift
//  SomaTracker
//
//  The conversation surface: it rises over the AI tab when the launcher bar is tapped, and collapses
//  back into it. The tab underneath is untouched, so switching this feature off returns the screen to
//  exactly what it was.
//
//  A conversation, not a form. Bubbles on a grouped background, one floating composer pill, and the
//  day's number kept as a small pill in the header so the chat is never blind to the day it is about.
//

import PhotosUI
import SwiftData
import SwiftUI

struct SomaChatSurface: View {
    @Bindable var session: SomaChatSession
    @Binding var isExpanded: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var speech = SpeechRecognitionService()

    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showMicAlert = false
    @State private var showClearConfirm = false
    /// "620 kcal left", in the header.
    @State private var dayPill = ""
    /// How far the surface has been pulled down by the header, damped. Without it a drag was invisible
    /// until it either collapsed the chat or did nothing.
    @State private var dragOffset: CGFloat = 0
    /// The one timer in this file, kept so it can be cancelled: an uncancellable one raised the keyboard
    /// over a chat the user had already closed.
    @State private var pendingFocus: Task<Void, Never>?
    /// Whether the keyboard belongs to the composer right now. The UIKit field enforces this, which is
    /// what makes the keyboard survive a send.
    @State private var composerActive = false

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            composer
        }
        .clipShape(topRoundedShape)
        // The surface bleeds to the physical bottom edge while its content stays inside the safe area,
        // so the composer never sits in the home-indicator zone. The background carries the same top
        // corners as the content, or square grey edges poke out above them.
        .background(topRoundedShape.fill(Color(.systemGroupedBackground)).ignoresSafeArea(edges: .bottom))
        .offset(y: dragOffset)
        .hideTabBarWithCoordinator()
        .accessibilityAddTraits(isExpanded ? .isModal : [])
        .photosPicker(isPresented: $showLibrary, selection: $session.pickerItems, maxSelectionCount: 5, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapturePicker(selectedImage: $capturedImage)
                .ignoresSafeArea()
                .background(Color.black.ignoresSafeArea())
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            session.attach(image: image)
            capturedImage = nil
            // The camera took the screen, so the conversation takes the keyboard back.
            composerActive = true
        }
        .sheet(isPresented: $session.needsPaywall) {
            SomaPaywallView()
        }
        .confirmationDialog(
            SpeechLanguage.resolved() == .arabic ? "تمسح المحادثة؟" : "Clear this conversation?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button(SpeechLanguage.resolved() == .arabic ? "امسح" : "Clear", role: .destructive) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.snappy(duration: 0.25)) { session.clear() }
            }
            Button(SpeechLanguage.resolved() == .arabic ? "إلغاء" : "Cancel", role: .cancel) {}
        } message: {
            Text(SpeechLanguage.resolved() == .arabic
                 ? "الوجبات المسجلة في يومك مش هتتأثر."
                 : "Entries already in your journal are kept either way.")
        }
        .onDisappear {
            // A safety net for an exit that did not run the collapse path, so the bar can never be left
            // hidden by this surface.
            pendingFocus?.cancel()
            composerActive = false
            dragOffset = 0
            TabBarCoordinator.setTabBarVisible(true)
        }
        .onAppear {
            refreshDayPill()
            armInitialFocus()
        }
        .onChange(of: session.messages.count) { _, _ in
            refreshDayPill()
        }
        .onChange(of: session.pendingPhotos.count) { _, _ in
            // Coming back from the photo library, the chat is ready to be typed in again.
            composerActive = true
        }
        .alert("Microphone Access Required", isPresented: $showMicAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Soma needs microphone access to record voice logs. Please enable it in iPhone Settings.")
        }
    }

    private var topRoundedShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
    }

    private var isArabic: Bool { SpeechLanguage.resolved() == .arabic }

    /// Opens the keyboard once the rise animation is done. A stored task, not a bare timer: the previous
    /// version fired whatever happened in between, which could raise the keyboard over a chat being
    /// closed or over a live recording.
    private func armInitialFocus() {
        pendingFocus?.cancel()
        pendingFocus = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, isExpanded else { return }
            composerActive = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color(.tertiaryLabel).opacity(0.5))
                .frame(width: 38, height: 5)
                .padding(.top, 8)

            HStack(spacing: 8) {
                SomaThinkingIndicator(isAnimating: session.isThinking, size: 26)

                Text("Soma")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(.label))

                Spacer(minLength: 8)

                if !dayPill.isEmpty {
                    Text(dayPill)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SomaColors.navy)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(SomaColors.navy.opacity(0.08), in: Capsule())
                        .contentTransition(.numericText())
                }

                if !session.messages.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "eraser")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(width: 32, height: 32)
                            .contentShape(Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear conversation")
                }

                Button {
                    collapse()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SomaColors.navy)
                        .frame(width: 32, height: 32)
                        .background(SomaColors.navy.opacity(0.10))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close chat")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Damped, and never upward: the surface can be pulled down, not pushed off the top.
                    dragOffset = max(0, value.translation.height) * 0.35
                }
                .onEnded { value in
                    if value.translation.height > 60 { collapse() }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { dragOffset = 0 }
                }
        )
    }

    private func refreshDayPill() {
        let pill = SomaToday(context: modelContext).remainingCaloriesShort
        withAnimation(.snappy(duration: 0.25)) {
            dayPill = pill
        }
    }

    // MARK: - Conversation

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if session.messages.isEmpty {
                    SomaChatBubble(message: .answer(greeting))
                        .transition(.opacity)
                } else {
                    separator(isArabic ? "النهاردة" : "Today")
                }

                ForEach(Array(session.messages.enumerated()), id: \.element.id) { index, message in
                    // A quiet time marker when a stretch of the conversation passes, the way Messages
                    // does it, so a long thread keeps its shape.
                    if index > 0, message.timestamp.timeIntervalSince(session.messages[index - 1].timestamp) > 600 {
                        separator(message.timestamp.formatted(date: .omitted, time: .shortened))
                    }

                    SomaChatBubble(message: message) {
                        Task {
                            await session.log(message: message, context: modelContext, subscription: subscriptionManager)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                }

                if session.isThinking { thinkingRow }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: session.messages.count)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: session.isThinking)
        }
        .defaultScrollAnchor(.bottom)
        // Neither interactive nor immediate dismissal: both close the keyboard on a scroll, and this
        // list scrolls itself to the newest message on every send. The conversation is meant to be typed
        // in, so the keyboard now only leaves when the user leaves the chat.
        .scrollDismissesKeyboard(.never)
    }

    private var greeting: String {
        isArabic
            ? "أنا Soma. اسألني عن سعرات النهاردة أو البروتين، أو قولي أكلت إيه وأنا أسجله."
            : "I'm Soma. Ask me about today's calories or protein, or just tell me what you ate and I'll log it."
    }

    private func separator(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(.tertiaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private var thinkingRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            SomaChatBubble(
                message: .answer(session.thinkingLabel),
                accessory: AnyView(
                    ShimmerProgressBar()
                        .frame(width: 120)
                )
            )

            Spacer(minLength: 0)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 10) {
            if !session.pendingPhotos.isEmpty { attachmentStrip }
            if speech.isRecordingLive { recordingStrip }
            if session.messages.isEmpty { suggestionChips }

            HStack(spacing: 8) {
                attachMenu

                // The field lives in UIKit so the return key sends without taking the keyboard with it.
                SomaComposerField(
                    text: $session.input,
                    placeholder: composerPlaceholder,
                    wantsFocus: composerActive,
                    onSend: { send() },
                    onFocusChange: { focused in composerActive = focused }
                )
                .frame(minHeight: 22)
                .padding(.horizontal, 2)

                trailingButton
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(SomaColors.white, in: Capsule())
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        // Scoped to the strips themselves: they appear and disappear around the pill, which used to make
        // the row jump with no animation.
        .animation(.snappy(duration: 0.2), value: session.pendingPhotos.isEmpty)
        .animation(.snappy(duration: 0.2), value: speech.isRecordingLive)
        .animation(.snappy(duration: 0.2), value: hasContent)
    }

    private var composerPlaceholder: String {
        isArabic ? "اكتب رسالة لسوما" : "Message Soma…"
    }

    /// What Soma can actually do, as one tap. Shown while the conversation is empty and gone once it
    /// has started, so it is a way in rather than clutter.
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(suggestionTexts, id: \.self) { text in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        session.input = text
                        send()
                    } label: {
                        Text(text)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(SomaColors.white, in: Capsule())
                            .overlay(Capsule().strokeBorder(SomaColors.navy.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private var suggestionTexts: [String] {
        isArabic
            ? ["باقيلي كام سعرة؟", "اقترحلي عشا", "أكلت كشري"]
            : ["How many calories left?", "Suggest dinner", "I ate koshary"]
    }

    private var attachMenu: some View {
        Menu {
            Button {
                showLibrary = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }

            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SomaColors.navy)
                .frame(width: 32, height: 32)
                .background(SomaColors.navy.opacity(0.08), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .opacity(session.isThinking ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(session.isThinking)
        .accessibilityLabel("Add a photo or take one")
    }

    private var trailingButton: some View {
        ZStack {
            if speech.isRecordingLive {
                Button {
                    stopRecording()
                } label: {
                    ZStack {
                        Circle().fill(SomaColors.coral).frame(width: 34, height: 34)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .transition(.scale)
                .accessibilityLabel("Stop recording")
            } else if hasContent {
                Button {
                    send()
                } label: {
                    ZStack {
                        Circle().fill(SomaColors.navy).frame(width: 34, height: 34)
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .opacity(session.isThinking ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(session.isThinking)
                .transition(.scale)
                .accessibilityLabel("Send to Soma")
            } else {
                Button {
                    startRecording()
                } label: {
                    ZStack {
                        Circle().fill(SomaColors.navy.opacity(0.08)).frame(width: 34, height: 34)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .opacity(session.isThinking ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(session.isThinking)
                .transition(.scale)
                .accessibilityLabel("Start a voice message")
            }
        }
    }

    private var hasContent: Bool {
        !session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !session.pendingPhotos.isEmpty
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(session.pendingPhotos.enumerated()), id: \.offset) { index, data in
                    if let image = UIImage(data: data) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityLabel("Attached photo \(index + 1) of \(session.pendingPhotos.count)")

                            Button {
                                session.pendingPhotos.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.black.opacity(0.6), in: Circle())
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove attached photo \(index + 1)")
                        }
                    }
                }
            }
        }
    }

    private var recordingStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(SomaColors.coral)
                .frame(width: 8, height: 8)

            Text(String(format: "%d:%02d", Int(speech.recordingDuration) / 60, Int(speech.recordingDuration) % 60))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.label))
                .monospacedDigit()

            AudioWaveformView(samples: speech.liveWaveformLevels, progress: 0, isLiveRecording: true)
                .frame(height: 26)

            Spacer(minLength: 0)

            // The strip is not tappable; the stop control is what the user needs to press.
            Text(isArabic ? "جاري التسجيل" : "Recording")
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SomaColors.white, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func send() {
        guard !session.isThinking else { return }
        Task {
            await session.send(context: modelContext, subscription: subscriptionManager)
        }
    }

    private func startRecording() {
        guard !session.isThinking else { return }
        // The keyboard's timer must not fire over a recording that is already running.
        pendingFocus?.cancel()
        composerActive = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard speech.startLiveTranscription() else {
            showMicAlert = true
            return
        }
    }

    private func stopRecording() {
        let recording = speech.stopLiveTranscription()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await session.sendVoice(
                transcript: recording.text,
                audioRelativePath: recording.relativePath,
                alternatives: recording.alternatives,
                samples: recording.samples,
                duration: recording.duration,
                context: modelContext,
                subscription: subscriptionManager
            )
        }
    }

    private func collapse() {
        pendingFocus?.cancel()
        composerActive = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            isExpanded = false
        }
    }
}

/// The bar the AI tab shows when the chat is available: same shape and weight as the plain input bar
/// it replaces, and tapping it opens the conversation.
struct SomaChatLauncher: View {
    let session: SomaChatSession
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                isExpanded = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SomaColors.navy)
                    .padding(.leading, 6)

                Text(placeholder)
                    .font(.system(size: 15))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(SomaColors.navy.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SomaColors.navy)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SomaColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open the Soma conversation")
    }

    private var placeholder: String {
        if let last = session.messages.last {
            return last.title.isEmpty ? last.text : last.title
        }
        return SpeechLanguage.resolved() == .arabic
            ? "اسأل Soma عن أي حاجة، أو اكتب وجبتك"
            : "Ask Soma anything, or describe a meal"
    }
}
