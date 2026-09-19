//
//  SomaChatSurface.swift
//  SomaTracker
//
//  The conversation surface: it rises over the AI tab when the launcher bar is tapped, and collapses
//  back into it. The tab underneath is untouched, so switching this feature off returns the screen to
//  exactly what it was.
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
    /// Today's numbers, shown under the title so the chat is never blind to the day it is about.
    @State private var daySummary = ""
    /// How far the surface has been pulled down by the header, damped. Without it a drag was invisible
    /// until it either collapsed the chat or did nothing.
    @State private var dragOffset: CGFloat = 0
    /// The one timer in this file, kept so it can be cancelled: an uncancellable one raised the keyboard
    /// over a chat the user had already closed.
    @State private var pendingFocus: Task<Void, Never>?

    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            // A plain sibling, deliberately. As a bottom inset of the scroll view it was rebuilt every
            // time the list's content changed, which is every send, and a rebuilt text field cannot hold
            // focus. The keyboard is kept away from it by the VStack respecting the keyboard's safe area,
            // not by anything in this file.
            composer
        }
        .clipShape(topRoundedShape)
        // The surface bleeds to the physical bottom edge while its content stays inside the safe area,
        // so the composer never sits in the home-indicator zone. The background carries the same top
        // corners as the content, or square grey edges poke out above the rounded header.
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
            dragOffset = 0
            TabBarCoordinator.setTabBarVisible(true)
        }
        .onAppear {
            refreshDaySummary()
            armInitialFocus()
        }
        .onChange(of: session.messages.count) { _, _ in
            refreshDaySummary()
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

    /// Opens the keyboard once the rise animation is done. A stored task, not a bare timer: the previous
    /// version fired whatever happened in between, which could raise the keyboard over a chat being
    /// closed or over a live recording.
    private func armInitialFocus() {
        pendingFocus?.cancel()
        pendingFocus = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled, isExpanded else { return }
            isComposerFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color(.tertiaryLabel).opacity(0.5))
                .frame(width: 38, height: 5)
                .padding(.top, 8)

            HStack(spacing: 10) {
                SomaThinkingIndicator(isAnimating: session.isThinking, size: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Soma")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(.label))

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }

                Spacer(minLength: 0)

                if !session.messages.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "eraser")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
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
                        .font(.system(size: 14, weight: .bold))
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
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
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
        .background(SomaColors.white)
    }

    private var subtitle: String {
        if session.isThinking { return session.thinkingLabel }
        if !daySummary.isEmpty { return daySummary }
        return SpeechLanguage.resolved() == .arabic
            ? "اسألني عن يومك أو سجّل وجبتك"
            : "Ask about your day, or log a meal"
    }

    private func refreshDaySummary() {
        let summary = SomaToday(context: modelContext).compactSummary
        withAnimation(.snappy(duration: 0.25)) {
            daySummary = summary
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if session.messages.isEmpty { emptyState }

                ForEach(session.messages) { message in
                    SomaChatBubble(message: message) {
                        Task {
                            await session.log(message: message, context: modelContext, subscription: subscriptionManager)
                        }
                    }
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                }

                if session.isThinking { thinkingRow }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: session.messages.count)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: session.isThinking)
        }
        .defaultScrollAnchor(.bottom)
        // Neither interactive nor immediate dismissal: both close the keyboard on a scroll, and this
        // list scrolls itself to the newest message on every send. The conversation is meant to be typed
        // in, so the keyboard now only leaves when the user leaves the chat.
        .scrollDismissesKeyboard(.never)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            SomaThinkingIndicator()

            Text(SpeechLanguage.resolved() == .arabic ? "اتكلم معايا" : "Talk to me")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(.label))

            Text(SpeechLanguage.resolved() == .arabic
                 ? "اكتب أو اتكلم عن وجبتك، ابعت صورة، أو اسألني عن سعرات النهاردة والبروتين والمية."
                 : "Describe a meal, send a photo, or ask me about today's calories, protein, water or steps.")
                .font(.system(size: 14))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
    }

    private var thinkingRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 12) {
                SomaThinkingIndicator(isAnimating: true, size: 44)

                VStack(alignment: .leading, spacing: 6) {
                    Text(session.thinkingLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.label))

                    ShimmerProgressBar()
                        .frame(width: 120)
                }
            }
            .padding(14)
            .background(SomaColors.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 2)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 46)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 10) {
            if !session.pendingPhotos.isEmpty { attachmentStrip }
            if speech.isRecordingLive { recordingStrip }

            HStack(spacing: 10) {
                attachMenu

                // A raised rounded field, the shape every other input in Soma uses. The bare text field
                // this replaces was the one place the chat looked like it had been bolted on.
                TextField(placeholder, text: $session.input)
                    .font(.system(size: 15))
                    .focused($isComposerFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                trailingButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        // Scoped to the strips themselves: they appear and disappear under the field, which used to make
        // the row jump by a strip's height with no animation.
        .animation(.snappy(duration: 0.2), value: session.pendingPhotos.isEmpty)
        .animation(.snappy(duration: 0.2), value: speech.isRecordingLive)
        .background(SomaColors.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(SomaColors.navy.opacity(0.07))
                .frame(height: 1)
        }
    }

    private var placeholder: String {
        SpeechLanguage.resolved() == .arabic
            ? "اكتب وجبتك أو سؤالك"
            : "Describe a meal, or ask a question"
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SomaColors.navy)
                .frame(width: 32, height: 32)
                .background(SomaColors.navy.opacity(0.08))
                .clipShape(Circle())
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
                        Circle().fill(SomaColors.coral).frame(width: 32, height: 32)
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
                        Circle().fill(SomaColors.navy).frame(width: 32, height: 32)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .opacity(session.isThinking ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(session.isThinking)
                .transition(.scale)
                .accessibilityLabel("Send")
            } else {
                Button {
                    startRecording()
                } label: {
                    ZStack {
                        Circle().fill(SomaColors.navy.opacity(0.08)).frame(width: 32, height: 32)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
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
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityLabel("Attached photo \(index + 1) of \(session.pendingPhotos.count)")

                            Button {
                                session.pendingPhotos.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
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

            // The strip is not tappable; the stop control below it is what the user needs to press.
            Text(SpeechLanguage.resolved() == .arabic ? "جاري التسجيل" : "Recording")
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
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
        isComposerFocused = false
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
        isComposerFocused = false
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
