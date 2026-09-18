//
//  AIView.swift
//  SomaTracker
//
//  Redesigned Soma AI Screen featuring iOS Voice Memos live recorder,
//  real-time speech transcription, instant food recognition, dedicated camera buttons,
//  and the editorial AI Journal.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AIView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIMealEntry.timestamp, order: .reverse) private var aiEntries: [AIMealEntry]

    // Unified Live Speech & Audio Recording Engine
    @State private var speechService = SpeechRecognitionService()

    // Camera & Photo Capture
    @State private var showCameraCapture = false
    @State private var capturedImage: UIImage? = nil

    // Smart Text Input
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    // Navigation & Feedback
    @State private var selectedEntryForDetail: AIMealEntry? = nil
    @State private var activeToastMessage: String? = nil
    @State private var showMicPermissionAlert = false

    // AI Thinking & Loading Animation State
    @State private var isAnalyzingAI: Bool = false
    @State private var analyzingType: AIAnalysisType = .text

    // Subscription & Paywall
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var lastQuickActionDate: Date = .distantPast

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                // 1. Top Section: Header, Live Voice Memos Recorder, Quick Text Bar
                Section {
                    VStack(spacing: 20) {
                        headerSection
                            .padding(.top, 4)

                        voiceMemosRecorderCard

                        quickTextInputBar
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 8, trailing: 18))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                // 2. AI Journal Entries (Native Swipe-to-Delete)
                if isAnalyzingAI || !aiEntries.isEmpty {
                    Section {
                        if isAnalyzingAI {
                            AILoadingCardView(analysisType: analyzingType)
                                .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                                ))
                        }

                        ForEach(aiEntries) { entry in
                            SwipeableJournalCardView(
                                entry: entry,
                                onSelect: {
                                    selectedEntryForDetail = entry
                                },
                                onDelete: {
                                    deleteJournalEntry(entry)
                                }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        HStack {
                            Text("AI MEAL JOURNAL")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(.secondaryLabel))

                            Spacer()

                            if isAnalyzingAI {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(SomaColors.navy)
                                        .frame(width: 6, height: 6)
                                    Text("ANALYZING...")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(SomaColors.navy)
                                }
                            } else {
                                Text("\(aiEntries.count) \(aiEntries.count == 1 ? "Entry" : "Entries")")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 14, leading: 22, bottom: 4, trailing: 22))
                        .listRowBackground(Color.clear)
                    }
                }

                // 3. Medical Disclaimer & Clearance
                Section {
                    Text("Nutritional estimates are for informational purposes only and are not medical advice. Consult a healthcare professional before starting any diet or nutrition plan.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    Color.clear
                        .frame(height: 110)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)

            // Dynamic Success / Recognition Toast
            if let message = activeToastMessage {
                toastBanner(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text("Soma AI")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(SomaColors.navy)

                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(SomaColors.navy)
                        .clipShape(Capsule())
                }
            }
        }
        .navigationDestination(item: $selectedEntryForDetail) { entry in
            AIMealDetailView(entry: entry)
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            CameraCapturePicker(selectedImage: $capturedImage)
                .ignoresSafeArea()
                .background(Color.black.ignoresSafeArea())
        }
        .sheet(isPresented: $showPaywall) {
            SomaPaywallView()
        }
        .onChange(of: showPaywall) { _, isShowing in
            // A photo held back by the paywall is analysed as soon as the user comes back.
            guard !isShowing, let image = capturedImage else { return }
            handleCapturedPhoto(image)
        }
        .alert("Microphone Access Required", isPresented: $showMicPermissionAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Soma needs microphone access to record voice meals and memos. Please enable it in iPhone Settings.")
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let image = newImage else { return }
            handleCapturedPhoto(image)
        }
        .onReceive(NotificationCenter.default.publisher(for: .somaTriggerQuickAction)) { notif in
            if let action = notif.object as? AIQuickAction {
                AppNavigationState.shared.pendingQuickAction = nil
                executeQuickAction(action)
            }
        }
        .onAppear {
            if let action = AppNavigationState.shared.pendingQuickAction {
                AppNavigationState.shared.pendingQuickAction = nil
                executeQuickAction(action)
            }
        }
    }

    private func executeQuickAction(_ action: AIQuickAction) {
        let now = Date()
        guard now.timeIntervalSince(lastQuickActionDate) > 0.8 else { return }
        lastQuickActionDate = now

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard subscriptionManager.canUseAIFeatures else {
            showPaywall = true
            return
        }
        guard !isAnalyzingAI else { return }
        switch action {
        case .camera:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showCameraCapture = true
            }
        case .voice:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if !speechService.isRecordingLive {
                    handleVoiceMemosButtonTap()
                }
            }
        }
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice & Food Intelligence")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(Color(.label))

                Text("Speak, snap, or type to log meals, macros, and hydration instantly.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPaywall = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text(subscriptionManager.isPro ? "PRO" : (subscriptionManager.remainingFreeScans > 0 ? "\(subscriptionManager.remainingFreeScans) FREE" : "UPGRADE"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.5)
                }
                .foregroundColor(subscriptionManager.isPro ? .white : SomaColors.navy)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(subscriptionManager.isPro ? SomaColors.navy : SomaColors.navy.opacity(0.10))
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    // MARK: - 2. iOS Voice Memos Live Recorder Card

    private var voiceMemosRecorderCard: some View {
        VStack(spacing: 16) {
            // Live Status & Timer Header
            HStack {
                if speechService.isRecordingLive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .opacity(speechService.isRecordingLive ? 1.0 : 0.4)

                        Text("LISTENING...")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.red)
                    }

                    Spacer()

                    // Elapsed Recording Timer
                    Text(formattedRecordingTime(speechService.recordingDuration))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(.label))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)

                        Text("VOICE MEMO LOG")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer()

                    // Interactive Speech Language Toggle
                    HStack(spacing: 4) {
                        ForEach(SpeechLanguage.allCases) { lang in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.snappy(duration: 0.18)) {
                                    speechService.selectedLanguage = lang
                                }
                            } label: {
                                Text(lang.displayName)
                                    .font(.system(size: 11, weight: speechService.selectedLanguage == lang ? .bold : .medium))
                                    .foregroundStyle(speechService.selectedLanguage == lang ? SomaColors.white : Color(.secondaryLabel))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        speechService.selectedLanguage == lang
                                            ? SomaColors.navy
                                            : Color(.tertiarySystemFill)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(speechService.isRecordingLive)
                        }
                    }
                }
            }

            // Real-Time Animated Waveform (dynamically reacts and scrolls with voice)
            AudioWaveformView(
                samples: speechService.isRecordingLive ? speechService.liveWaveformLevels : [],
                progress: 1.0,
                isLiveRecording: speechService.isRecordingLive
            )
            .frame(height: 38)

            // Live Transcription Box (Words stream in real time as you talk!)
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))

                VStack(spacing: 4) {
                    if speechService.isRecordingLive {
                        if speechService.liveTranscribedText.isEmpty {
                            Text(speechService.selectedLanguage == .arabic
                                ? "استمع الآن... تحدث عما تناولته أو شربته (اضغط المربع للأكل/الحفظ)"
                                : "Listening... Speak what you ate or drank (tap red square to log)")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.secondaryLabel))
                                .italic()
                        } else {
                            Text(speechService.liveTranscribedText)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(.label))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .animation(.easeOut(duration: 0.15), value: speechService.liveTranscribedText)
                        }
                    } else {
                        Text(speechService.selectedLanguage == .arabic
                            ? "اضغط على زر التسجيل وتحدث عن وجبتك، أو التقط صورة لها."
                            : "Tap the red record button to speak, or snap a photo of your meal.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(minHeight: 52)

            // Controls: Record Button (Center) and Camera Button (Right)
            HStack(spacing: 32) {
                // Left spacer for visual balance
                Color.clear
                    .frame(width: 48, height: 48)

                // Center: iOS Voice Memos Tactile Record Button
                Button {
                    handleVoiceMemosButtonTap()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color(.systemGray4), lineWidth: 3.5)
                            .frame(width: 68, height: 68)

                        if speechService.isRecordingLive {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red)
                                .frame(width: 26, height: 26)
                                .transition(.scale)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 54, height: 54)
                                .transition(.scale)
                        }
                    }
                }
                .buttonStyle(.borderless)

                // Right: Dedicated Camera Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if subscriptionManager.canUseAIFeatures {
                        showCameraCapture = true
                    } else {
                        showPaywall = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 48, height: 48)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(SomaColors.navy)
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Snap Meal Photo")
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    // MARK: - 3. Smart Quick-Log Text Input Bar

    private var quickTextInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SomaColors.navy)
                .padding(.leading, 6)

            TextField(
                "Describe meal or water (e.g. chicken salad)...",
                text: $inputText
            )
            .font(.system(size: 15))
            .focused($isInputFocused)
            .submitLabel(.send)
            .onSubmit {
                processTextInput()
            }

            if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    processTextInput()
                } label: {
                    ZStack {
                        Circle()
                            .fill(SomaColors.navy)
                            .frame(width: 32, height: 32)

                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.borderless)
                .transition(.scale)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    // MARK: - 4. Actions & Logic

    private func deleteJournalEntry(_ entry: AIMealEntry) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let dayLog = entry.dailyLog
        withAnimation(.snappy(duration: 0.25)) {
            entry.deleteWithSyncedEntries(in: modelContext)
        }
        // Health keeps its own copy, so a removal has to be mirrored too.
        Task { await HealthSyncService.shared.syncDay(dayLog) }
        showToast("Deleted \(entry.title.isEmpty ? "meal entry" : entry.title)")
    }

    private func resolveMealLocation(from analysisLocation: String) async -> String {
        let gpsLocation = await LocationService.shared.fetchCurrentLocation()
        if !analysisLocation.isEmpty && analysisLocation != "Voice Memo" && analysisLocation != "Quick AI Log" && analysisLocation != "Captured with Camera" {
            if !gpsLocation.isEmpty && !analysisLocation.contains(gpsLocation) {
                return "\(analysisLocation) · \(gpsLocation)"
            }
            return analysisLocation
        }
        return !gpsLocation.isEmpty ? gpsLocation : "Soma AI Log"
    }

    /// Placeholder values the AI echoes back when it has no real location to report.
    private static let locationPlaceholders: Set<String> = [
        "Voice Memo", "Quick AI Log", "Captured with Camera"
    ]

    /// Shown when the cloud call failed and the on-device engine found nothing either: the user
    /// needs to know Soma AI was unreachable, not that their own log was empty.
    private var unreachableAIMessage: String {
        localized("تعذر الوصول إلى Soma AI. تحقق من الاتصال وحاول مرة أخرى.", "Couldn't reach Soma AI. Please try again.")
    }

    private func localized(_ arabic: String, _ english: String) -> String {
        speechService.selectedLanguage == .arabic ? arabic : english
    }

    /// Location stored the moment an entry is created: the AI's own when it reported one,
    /// otherwise a neutral label. `patchLocation` swaps in the geocoded value once it resolves.
    private func provisionalLocation(from analysisLocation: String) -> String {
        let trimmed = analysisLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || Self.locationPlaceholders.contains(trimmed) ? "Soma AI Log" : trimmed
    }

    /// Reverse geocoding is a network round trip, so it runs after the entry is saved and on
    /// screen, and the resolved value is patched in behind it. Awaiting it first added a dead
    /// beat to every AI log and let a geocoder hiccup delay the entry itself.
    private func patchLocation(of entry: AIMealEntry, from analysisLocation: String) {
        Task {
            let resolved = await resolveMealLocation(from: analysisLocation)
            guard !resolved.isEmpty, resolved != entry.location, entry.modelContext != nil else { return }
            entry.location = resolved
            do {
                try modelContext.save()
            } catch {
                print("[AIView] Location patch failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Logic & Actions

    private func handleVoiceMemosButtonTap() {
        if speechService.isRecordingLive {
            // STOP RECORDING
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let result = speechService.stopLiveTranscription()

            // Guard against micro-taps (< 0.8s)
            guard result.duration >= 0.8 else {
                if let url = result.audioURL {
                    try? FileManager.default.removeItem(at: url)
                }
                showToast(speechService.selectedLanguage == .arabic ? "التسجيل قصير جداً. تحدث بما أكلته ثم أوقف التسجيل." : "Recording too short. Speak and tap to stop.")
                return
            }

            var effectiveSpeech = !result.text.isEmpty
                ? result.text
                : speechService.liveTranscribedText

            withAnimation(.snappy(duration: 0.25)) {
                analyzingType = .voice
                isAnalyzingAI = true
            }

            Task {
                // If live transcription is empty, attempt file transcription
                if effectiveSpeech.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = result.audioURL {
                    let fileTranscribed = await speechService.transcribeAudioFile(at: url)
                    if !fileTranscribed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        effectiveSpeech = fileTranscribed
                    }
                }

                let trimmedSpeech = effectiveSpeech.trimmingCharacters(in: .whitespacesAndNewlines)

                // Strict speech validation: If no speech was transcribed at all, do NOT create fake logs or contact AI
                guard !trimmedSpeech.isEmpty else {
                    if let url = result.audioURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    await MainActor.run {
                        withAnimation(.snappy(duration: 0.35)) {
                            isAnalyzingAI = false
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        showToast(speechService.selectedLanguage == .arabic ? "لم يتم سماع أي كلام. تحدث بما أكلته أو شربته." : "No speech detected. Please speak what you ate or drank.")
                    }
                    return
                }

                // Hydration is exact from on-device parsing, so it skips the cloud call
                // entirely rather than spending a scan on a glass of water.
                let localWater = FoodNutritionDatabase.shared.parseInput(trimmedSpeech)
                if localWater.isWater {
                    await MainActor.run {
                        logLocalHydration(
                            amountML: localWater.waterML,
                            summary: localWater.summary,
                            story: trimmedSpeech,
                            voiceRelativePath: result.relativePath,
                            waveformSamples: result.samples,
                            duration: result.duration
                        )
                        withAnimation(.snappy(duration: 0.35)) {
                            isAnalyzingAI = false
                        }
                    }
                    return
                }

                // Parse speech via AI Router (uses Gemini Flash if configured, or on-device FoodNutritionDatabase)
                let analysis = await AIRouter.shared.processMultimodalMeal(
                    notes: trimmedSpeech,
                    photos: [],
                    audioURL: result.audioURL,
                    directTranscription: trimmedSpeech,
                    alternativeTranscriptions: result.alternatives
                )

                // The engines recognise water too, including phrasings the local parser misses
                // ("شربت ٥٠٠ مل مياه"). A water answer belongs in the hydration tracker, not in the
                // food log, and it never spends a free scan, exactly like the local path above.
                if analysis.isWaterLog {
                    await MainActor.run {
                        logLocalHydration(
                            amountML: analysis.waterML,
                            summary: analysis.storyNarrative.isEmpty ? analysis.title : analysis.storyNarrative,
                            story: trimmedSpeech,
                            voiceRelativePath: result.relativePath,
                            waveformSamples: result.samples,
                            duration: result.duration
                        )
                        withAnimation(.snappy(duration: 0.35)) {
                            isAnalyzingAI = false
                        }
                    }
                    return
                }

                // Guard against "No Food Detected"
                guard !analysis.isNoFood, analysis.title != "No Food Detected" else {
                    if let url = result.audioURL {
                        try? FileManager.default.removeItem(at: url)
                    }
                    await MainActor.run {
                        withAnimation(.snappy(duration: 0.35)) {
                            isAnalyzingAI = false
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        let emptyResultMessage = analysis.engine == .onDeviceFallback
                            ? unreachableAIMessage
                            : localized("لم يتم التعرف على طعام أو شراب. برجاء المحاولة مرة أخرى.", "No food or drink detected. Please try again.")
                        showToast(emptyResultMessage)
                    }
                    return
                }

                let finalLocation = provisionalLocation(from: analysis.location)

                await MainActor.run {
                    let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)
                    let aiEntryId = UUID()

                    let story = !analysis.storyNarrative.isEmpty
                        ? analysis.storyNarrative
                        : (!trimmedSpeech.isEmpty ? trimmedSpeech : analysis.title)

                    // Hydration is decided before the cloud call from what the user actually
                    // said, so nothing here re-reads the AI's own narrative for water: doing that
                    // turned meals the model merely described as "with a glass of water" into a
                    // fabricated hydration log whenever the call misbehaved.
                    let foodEntry = FoodEntry(
                        name: analysis.title,
                        calories: analysis.calories,
                        proteinG: analysis.proteinG,
                        carbsG: analysis.carbsG,
                        fatG: analysis.fatG,
                        mealType: "Voice Log",
                        timestamp: .now,
                        aiMealEntryId: aiEntryId
                    )
                    todayLog.foodEntries.append(foodEntry)

                    let aiEntry = AIMealEntry(
                        id: aiEntryId,
                        title: analysis.title,
                        location: finalLocation,
                        storyText: story,
                        calories: analysis.calories,
                        proteinG: analysis.proteinG,
                        carbsG: analysis.carbsG,
                        fatG: analysis.fatG,
                        photoDataList: [],
                        voiceAudioRelativePath: result.relativePath,
                        voiceWaveformSamples: result.samples,
                        voiceDurationSeconds: result.duration,
                        breakdownNotes: analysis.storyNarrative
                    )
                    aiEntry.dailyLog = todayLog
                    modelContext.insert(aiEntry)

                    let saved = persistContext()
                    if saved { subscriptionManager.consumeFreeScanIfFreeUser() }
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                    guard saved else { return }
                    patchLocation(of: aiEntry, from: analysis.location)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    if subscriptionManager.isPro {
                        showToast("Logged \(analysis.title) · \(analysis.calories) kcal")
                    } else if subscriptionManager.remainingFreeScans > 0 {
                        showToast("Logged \(analysis.title) · \(subscriptionManager.remainingFreeScans) free logs left")
                    } else {
                        showToast("Logged \(analysis.title) · Free trial completed")
                    }
                }
            }

        } else {
            // START RECORDING
            guard !isAnalyzingAI else { return }
            guard subscriptionManager.canUseAIFeatures else {
                showPaywall = true
                return
            }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            Task {
                if speechService.checkMicrophoneStatus() == .denied {
                    await MainActor.run {
                        showMicPermissionAlert = true
                    }
                    return
                }

                let authorized = await speechService.requestAuthorization()
                guard authorized else {
                    await MainActor.run {
                        if speechService.checkMicrophoneStatus() == .denied {
                            showMicPermissionAlert = true
                        } else {
                            showToast("Microphone permission is required to record.")
                        }
                    }
                    return
                }

                await MainActor.run {
                    let started = speechService.startLiveTranscription()
                    if !started {
                        let msg = speechService.lastErrorMessage ?? "Unable to start microphone recording."
                        showToast(msg)
                    }
                }
            }
        }
    }

    private func processTextInput() {
        let query = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        guard !isAnalyzingAI else { return }

        // Hydration is exact from on-device parsing: no cloud round trip, no AI credit.
        let localWater = FoodNutritionDatabase.shared.parseInput(query)
        if localWater.isWater {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            inputText = ""
            isInputFocused = false
            logLocalHydration(amountML: localWater.waterML, summary: localWater.summary, story: query)
            return
        }

        guard subscriptionManager.canUseAIFeatures else {
            showPaywall = true
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        isInputFocused = false

        withAnimation(.snappy(duration: 0.25)) {
            analyzingType = .text
            isAnalyzingAI = true
        }

        Task {
            let analysis = await AIRouter.shared.processMultimodalMeal(
                notes: query,
                photos: [],
                audioURL: nil
            )

            // Water answered by an engine still belongs in the hydration tracker, not the food log.
            if analysis.isWaterLog {
                await MainActor.run {
                    logLocalHydration(
                        amountML: analysis.waterML,
                        summary: analysis.storyNarrative.isEmpty ? analysis.title : analysis.storyNarrative,
                        story: query
                    )
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                }
                return
            }

            // Guard against non-food text inputs
            guard !analysis.isNoFood, analysis.title != "No Food Detected" else {
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    let emptyResultMessage = analysis.engine == .onDeviceFallback
                        ? unreachableAIMessage
                        : localized("لم يتم التعرف على طعام أو شراب في النص.", "No food or drink recognized in text.")
                    showToast(emptyResultMessage)
                }
                return
            }

            let finalLocation = provisionalLocation(from: analysis.location)

            await MainActor.run {
                let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)
                let aiEntryId = UUID()

                // Hydration was already decided from the typed text before the cloud call, so the
                // result is never re-read for water here.
                let foodEntry = FoodEntry(
                    name: analysis.title,
                    calories: analysis.calories,
                    proteinG: analysis.proteinG,
                    carbsG: analysis.carbsG,
                    fatG: analysis.fatG,
                    mealType: "AI Log",
                    timestamp: .now,
                    aiMealEntryId: aiEntryId
                )
                todayLog.foodEntries.append(foodEntry)

                let aiEntry = AIMealEntry(
                    id: aiEntryId,
                    title: analysis.title,
                    location: finalLocation,
                    storyText: query,
                    calories: analysis.calories,
                    proteinG: analysis.proteinG,
                    carbsG: analysis.carbsG,
                    fatG: analysis.fatG,
                    photoDataList: [],
                    voiceAudioRelativePath: nil,
                    voiceWaveformSamples: [],
                    voiceDurationSeconds: 0.0,
                    breakdownNotes: analysis.storyNarrative
                )
                aiEntry.dailyLog = todayLog
                modelContext.insert(aiEntry)

                let saved = persistContext()
                if saved { subscriptionManager.consumeFreeScanIfFreeUser() }
                withAnimation(.snappy(duration: 0.35)) {
                    isAnalyzingAI = false
                }
                guard saved else { return }
                patchLocation(of: aiEntry, from: analysis.location)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if subscriptionManager.isPro {
                    showToast("Logged \(analysis.title) · \(analysis.calories) kcal")
                } else if subscriptionManager.remainingFreeScans > 0 {
                    showToast("Logged \(analysis.title) · \(subscriptionManager.remainingFreeScans) free logs left")
                } else {
                    showToast("Logged \(analysis.title) · Free trial completed")
                }
            }
        }
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        guard !isAnalyzingAI else { return }
        guard subscriptionManager.canUseAIFeatures else {
            showPaywall = true
            return
        }
        // Clear the shot only once it is actually being analysed, so visiting the paywall
        // first doesn't cost the user the photo they just took.
        capturedImage = nil
        guard let jpegData = downscaledJPEGData(from: image) else { return }

        withAnimation(.snappy(duration: 0.25)) {
            analyzingType = .photo
            isAnalyzingAI = true
        }

        Task {
            let analysis = await AIRouter.shared.processMultimodalMeal(
                notes: "Meal Photo",
                photos: [jpegData],
                audioURL: nil
            )

            // A photo of a glass of water is hydration, not a zero-calorie meal.
            if analysis.isWaterLog {
                await MainActor.run {
                    logLocalHydration(
                        amountML: analysis.waterML,
                        summary: analysis.storyNarrative.isEmpty ? analysis.title : analysis.storyNarrative,
                        story: "Meal Photo",
                        photos: [jpegData]
                    )
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                }
                return
            }

            // Guard against non-food photos (e.g. pets, objects, landscapes)
            guard !analysis.isNoFood, analysis.title != "No Food Detected" else {
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    let emptyResultMessage = analysis.engine == .onDeviceFallback
                        ? unreachableAIMessage
                        : localized("لم يتم التعرف على طعام في الصورة.", "No food detected in photo.")
                    showToast(emptyResultMessage)
                }
                return
            }

            let finalLocation = provisionalLocation(from: analysis.location)

            await MainActor.run {
                let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)
                let aiEntryId = UUID()

                let foodEntry = FoodEntry(
                    name: analysis.title,
                    calories: analysis.calories,
                    proteinG: analysis.proteinG,
                    carbsG: analysis.carbsG,
                    fatG: analysis.fatG,
                    mealType: "Photo Log",
                    timestamp: .now,
                    aiMealEntryId: aiEntryId
                )
                todayLog.foodEntries.append(foodEntry)

                let aiEntry = AIMealEntry(
                    id: aiEntryId,
                    title: analysis.title,
                    location: finalLocation,
                    storyText: analysis.storyNarrative,
                    calories: analysis.calories,
                    proteinG: analysis.proteinG,
                    carbsG: analysis.carbsG,
                    fatG: analysis.fatG,
                    photoDataList: [jpegData],
                    voiceAudioRelativePath: nil,
                    voiceWaveformSamples: [],
                    voiceDurationSeconds: 0.0,
                    breakdownNotes: "Analyzed with Soma AI."
                )
                aiEntry.dailyLog = todayLog
                modelContext.insert(aiEntry)

                let saved = persistContext()
                if saved { subscriptionManager.consumeFreeScanIfFreeUser() }
                withAnimation(.snappy(duration: 0.35)) {
                    isAnalyzingAI = false
                }
                guard saved else { return }
                patchLocation(of: aiEntry, from: analysis.location)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                if subscriptionManager.isPro {
                    showToast("Logged \(analysis.title) · \(analysis.calories) kcal")
                } else if subscriptionManager.remainingFreeScans > 0 {
                    showToast("Logged \(analysis.title) · \(subscriptionManager.remainingFreeScans) free logs left")
                } else {
                    showToast("Logged \(analysis.title) · Free trial completed")
                }
                capturedImage = nil
            }
        }
    }

    /// Persists the context and reports whether the write actually landed.
    /// Every logging path used `try? save()`, so a failed write still showed a success toast.
    @discardableResult
    private func persistContext() -> Bool {
        do {
            try modelContext.save()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            showToast(speechService.selectedLanguage == .arabic
                ? "تعذر حفظ السجل. برجاء المحاولة مرة أخرى."
                : "Couldn't save your log. Please try again.")
            return false
        }

        // Every AI log lands in today's log, so mirroring that day into Health here covers all
        // five logging paths, and later edits or deletes, without per-site bookkeeping.
        Task { await HealthSyncService.shared.syncDay(DailyLog.fetchOrCreateToday(context: modelContext)) }
        return true
    }

    /// Hydration is parsed on-device: exact numbers, no cloud round trip, and it never
    /// spends a free AI scan.
    private func logLocalHydration(
        amountML: Int,
        summary: String,
        story: String,
        photos: [Data] = [],
        voiceRelativePath: String? = nil,
        waveformSamples: [Float] = [],
        duration: TimeInterval = 0
    ) {
        AIMealEntry.logHydration(
            amountML: amountML,
            story: story,
            summary: summary,
            photos: photos,
            voiceRelativePath: voiceRelativePath,
            waveformSamples: waveformSamples,
            duration: duration,
            in: modelContext
        )

        if persistContext() {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast(summary)
        }
    }

    /// Gemini does not need a 12 MP plate. Shrinking to 1024 px keeps the base64 payload
    /// (built on the main actor) roughly ten times smaller.
    private func downscaledJPEGData(from image: UIImage, maxDimension: CGFloat = 1_024, quality: CGFloat = 0.82) -> Data? {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: targetSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activeToastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeInOut(duration: 0.25)) {
                activeToastMessage = nil
            }
        }
    }

    private func formattedRecordingTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        let centis = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }

    private func toastBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SomaColors.emerald)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
                .overlay(
                    Capsule()
                        .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                )
        )
        .padding(.top, 10)
    }
}

// MARK: - AI Analysis Mode

enum AIAnalysisType {
    case text
    case voice
    case photo

    var title: String {
        switch self {
        case .text: return "Analyzing Meal Notes..."
        case .voice: return "Transcribing Voice Memo..."
        case .photo: return "Analyzing Meal Photo..."
        }
    }

    var subtitle: String {
        switch self {
        case .text: return "Estimating ingredients, portions & macros"
        case .voice: return "Extracting nutritional breakdown & context"
        case .photo: return "Identifying items, portions & calories"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "sparkles"
        case .voice: return "waveform"
        case .photo: return "camera.viewfinder"
        }
    }
}

// MARK: - Soma-Themed AI Loading Animation Card

struct AILoadingCardView: View {
    let analysisType: AIAnalysisType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                BreathingIconBadge(systemImage: analysisType.systemImage)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(analysisType.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color(.label))

                        Text("SOMA AI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(SomaColors.navy)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SomaColors.navy.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(analysisType.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                BouncingDotsView()
                    .padding(.trailing, 4)
            }

            ShimmerProgressBar()
                .padding(.top, 2)
        }
        .padding(14)
        .background(SomaColors.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SomaColors.navy.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

private struct BreathingIconBadge: View {
    let systemImage: String
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(SomaColors.navy.opacity(0.08))
                .frame(width: 44, height: 44)

            Circle()
                .stroke(SomaColors.navy.opacity(0.18), lineWidth: 1.5)
                .frame(width: 44, height: 44)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.7)

            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(SomaColors.navy)
                .scaleEffect(isPulsing ? 1.06 : 0.94)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

private struct BouncingDotsView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(SomaColors.navy)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1.25 : 0.75)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.16),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

private struct ShimmerProgressBar: View {
    @State private var shimmerPhase: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill).opacity(0.7))
                    .frame(height: 3)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                SomaColors.navy.opacity(0.08),
                                SomaColors.navy.opacity(0.85),
                                SomaColors.navy.opacity(0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.4, height: 3)
                    .offset(x: max(0, min(geo.size.width * 0.6, (shimmerPhase + 1.0) / 2.0 * geo.size.width * 0.6)))
            }
        }
        .frame(height: 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                shimmerPhase = 1.0
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIView()
    }
    .modelContainer(PreviewData.container)
}
