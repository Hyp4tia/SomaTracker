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

    @FocusState private var isComposerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
                // As a bottom inset of the scroll view the composer rides above the keyboard, which is
                // what a chat is expected to do.
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // The surface bleeds to the physical bottom edge while its content stays inside the safe
        // area, so the composer never sits in the home-indicator zone.
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .hideTabBarWithCoordinator()
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
        .onDisappear {
            // A safety net for an exit that did not run the collapse path, so the bar can never be left
            // hidden by this surface.
            TabBarCoordinator.setTabBarVisible(true)
        }
        .onAppear {
            // The conversation opens ready to type: asking for the keyboard after the rise animation
            // avoids fighting it for the same frames.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isComposerFocused = true
            }
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color(.tertiaryLabel).opacity(0.5))
                .frame(width: 38, height: 5)
                .padding(.top, 8)

            HStack(spacing: 10) {
                SomaThinkingIndicator()
                    .frame(width: 30, height: 30)
                    .scaleEffect(0.75)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Soma")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(.label))

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if !session.messages.isEmpty {
                    Button(role: .destructive) {
                        withAnimation(.snappy(duration: 0.25)) {
                            session.clear()
                        }
                    } label: {
                        Image(systemName: "eraser")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(width: 32, height: 32)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
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
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 60 { collapse() }
                }
        )
        .background(SomaColors.white)
    }

    private var subtitle: String {
        session.isThinking
            ? session.thinkingLabel
            : (SpeechLanguage.resolved() == .arabic ? "اسألني عن يومك أو سجّل وجبتك" : "Ask about your day, or log a meal")
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
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                if session.isThinking { thinkingRow }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: session.messages.count)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: session.isThinking)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            SomaThinkingIndicator()
                .frame(width: 44, height: 44)

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
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SomaColors.navy.opacity(0.07), lineWidth: 1)
        )
    }

    private var thinkingRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 12) {
                SomaThinkingIndicator()

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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SomaColors.navy.opacity(0.07), lineWidth: 1)
            )

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

                TextField(placeholder, text: $session.input)
                    .font(.system(size: 15))
                    .focused($isComposerFocused)
                    .submitLabel(.send)
                    .onSubmit { send() }

                trailingButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
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
        }
        .buttonStyle(.plain)
        .disabled(session.isThinking)
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
                }
                .buttonStyle(.plain)
                .transition(.scale)
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
                }
                .buttonStyle(.plain)
                .disabled(session.isThinking)
                .transition(.scale)
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
                }
                .buttonStyle(.plain)
                .transition(.scale)
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

                            Button {
                                session.pendingPhotos.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(3)
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

            Text(String(format: "%.1fs", speech.recordingDuration))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(.label))
                .monospacedDigit()

            AudioWaveformView(samples: speech.liveWaveformLevels, progress: 0, isLiveRecording: true)
                .frame(height: 26)

            Spacer(minLength: 0)

            Text(SpeechLanguage.resolved() == .arabic ? "اضغط للإيقاف" : "Tap to stop")
                .font(.system(size: 11))
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - Actions

    private func send() {
        guard !session.isThinking else { return }
        isComposerFocused = false
        Task {
            await session.send(context: modelContext, subscription: subscriptionManager)
        }
    }

    private func startRecording() {
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
                duration: recording.duration,
                context: modelContext,
                subscription: subscriptionManager
            )
        }
    }

    private func collapse() {
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
