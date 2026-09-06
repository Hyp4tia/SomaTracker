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
    @State private var showMultimodalSheet = false

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
        .sheet(isPresented: $showMultimodalSheet) {
            AIMultimodalInputSheet { newEntry in
                newEntry.syncToFoodEntry(in: modelContext)
                selectedEntryForDetail = newEntry
            }
        }
        .sheet(isPresented: $showPaywall) {
            SomaPaywallView()
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard subscriptionManager.canUseAIFeatures else {
            showPaywall = true
            return
        }
        switch action {
        case .camera:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showCameraCapture = true
            }
        case .voice:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                "Describe meal or water (e.g. Big Mac)...",
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
        withAnimation(.snappy(duration: 0.25)) {
            entry.deleteWithSyncedEntries(in: modelContext)
        }
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

                // Parse speech via AI Router (uses Gemini Flash if configured, or on-device FoodNutritionDatabase)
                let analysis = await AIRouter.shared.processMultimodalMeal(
                    notes: trimmedSpeech,
                    photos: [],
                    audioURL: result.audioURL,
                    directTranscription: trimmedSpeech,
                    alternativeTranscriptions: result.alternatives
                )

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
                        showToast(speechService.selectedLanguage == .arabic ? "لم يتم التعرف على طعام أو شراب. برجاء المحاولة مرة أخرى." : "No food or drink detected. Please try again.")
                    }
                    return
                }

                let finalLocation = await resolveMealLocation(from: analysis.location)

                await MainActor.run {
                    let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)
                    let aiEntryId = UUID()

                    let story = !analysis.storyNarrative.isEmpty
                        ? analysis.storyNarrative
                        : (!trimmedSpeech.isEmpty ? trimmedSpeech : analysis.title)

                    let parsedWaterCheck = FoodNutritionDatabase.shared.parseInput(story)
                    if parsedWaterCheck.isWater {
                        let water = WaterEntry(
                            amount: parsedWaterCheck.waterML,
                            timestamp: .now,
                            label: "AI Voice Log",
                            aiMealEntryId: aiEntryId
                        )
                        todayLog.waterEntries.append(water)

                        let aiEntry = AIMealEntry(
                            id: aiEntryId,
                            title: "Hydration (\(parsedWaterCheck.waterML) ml)",
                            location: finalLocation,
                            storyText: story,
                            calories: 0,
                            proteinG: 0,
                            carbsG: 0,
                            fatG: 0,
                            photoDataList: [],
                            voiceAudioRelativePath: result.relativePath,
                            voiceWaveformSamples: result.samples,
                            voiceDurationSeconds: result.duration,
                            breakdownNotes: parsedWaterCheck.summary
                        )
                        aiEntry.dailyLog = todayLog
                        modelContext.insert(aiEntry)

                        try? modelContext.save()
                        withAnimation(.snappy(duration: 0.35)) {
                            isAnalyzingAI = false
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showToast(parsedWaterCheck.summary)
                        return
                    }

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

                    subscriptionManager.consumeFreeScanIfFreeUser()
                    try? modelContext.save()
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
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

            // Guard against non-food text inputs
            guard !analysis.isNoFood, analysis.title != "No Food Detected" else {
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    showToast(speechService.selectedLanguage == .arabic ? "لم يتم التعرف على طعام أو شراب في النص." : "No food or drink recognized in text.")
                }
                return
            }

            let finalLocation = await resolveMealLocation(from: analysis.location)

            await MainActor.run {
                let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)
                let aiEntryId = UUID()

                let parsedWaterCheck = FoodNutritionDatabase.shared.parseInput(query)
                if parsedWaterCheck.isWater {
                    let water = WaterEntry(
                        amount: parsedWaterCheck.waterML,
                        timestamp: .now,
                        label: "AI Log",
                        aiMealEntryId: aiEntryId
                    )
                    todayLog.waterEntries.append(water)

                    let aiEntry = AIMealEntry(
                        id: aiEntryId,
                        title: "Hydration (\(parsedWaterCheck.waterML) ml)",
                        location: finalLocation,
                        storyText: query,
                        calories: 0,
                        proteinG: 0,
                        carbsG: 0,
                        fatG: 0,
                        photoDataList: [],
                        voiceAudioRelativePath: nil,
                        voiceWaveformSamples: [],
                        voiceDurationSeconds: 0.0,
                        breakdownNotes: parsedWaterCheck.summary
                    )
                    aiEntry.dailyLog = todayLog
                    modelContext.insert(aiEntry)

                    subscriptionManager.consumeFreeScanIfFreeUser()
                    try? modelContext.save()
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    if subscriptionManager.isPro {
                        showToast(parsedWaterCheck.summary)
                    } else if subscriptionManager.remainingFreeScans > 0 {
                        showToast("\(parsedWaterCheck.summary) · \(subscriptionManager.remainingFreeScans) free logs left")
                    } else {
                        showToast("\(parsedWaterCheck.summary) · Free trial completed")
                    }
                    return
                }

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

                subscriptionManager.consumeFreeScanIfFreeUser()
                try? modelContext.save()
                withAnimation(.snappy(duration: 0.35)) {
                    isAnalyzingAI = false
                }
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
        capturedImage = nil
        guard subscriptionManager.canUseAIFeatures else {
            showPaywall = true
            return
        }
        guard let jpegData = image.jpegData(compressionQuality: 0.82) else { return }

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

            // Guard against non-food photos (e.g. pets, objects, landscapes)
            guard !analysis.isNoFood, analysis.title != "No Food Detected" else {
                await MainActor.run {
                    withAnimation(.snappy(duration: 0.35)) {
                        isAnalyzingAI = false
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    showToast(speechService.selectedLanguage == .arabic ? "لم يتم التعرف على طعام في الصورة." : "No food detected in photo.")
                }
                return
            }

            let finalLocation = await resolveMealLocation(from: analysis.location)

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

                subscriptionManager.consumeFreeScanIfFreeUser()
                try? modelContext.save()
                withAnimation(.snappy(duration: 0.35)) {
                    isAnalyzingAI = false
                }
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

    private func saveNutritionResult(
        parsed: ParsedNutritionResult,
        originalText: String,
        audioRelativePath: String?,
        waveformSamples: [Float],
        photos: [Data]
    ) {
        let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)
        let aiEntryId = UUID()

        if parsed.isWater {
            let water = WaterEntry(
                amount: parsed.waterML,
                timestamp: .now,
                label: "AI Voice Log",
                aiMealEntryId: aiEntryId
            )
            todayLog.waterEntries.append(water)

            let aiEntry = AIMealEntry(
                id: aiEntryId,
                title: "Hydration (\(parsed.waterML) ml)",
                location: "Logged with Soma AI",
                storyText: originalText,
                calories: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
                photoDataList: photos,
                voiceAudioRelativePath: audioRelativePath,
                voiceWaveformSamples: waveformSamples,
                voiceDurationSeconds: audioRelativePath != nil ? Double(waveformSamples.count) * 0.06 : 0.0,
                breakdownNotes: parsed.summary
            )
            aiEntry.dailyLog = todayLog
            modelContext.insert(aiEntry)

            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showToast("Logged \(parsed.waterML) ml of water")
            return
        }

        // 1. Food Entry in Daily Tracker
        let foodEntry = FoodEntry(
            name: parsed.title,
            calories: parsed.calories,
            proteinG: parsed.proteinG,
            carbsG: parsed.carbsG,
            fatG: parsed.fatG,
            mealType: "AI Log",
            timestamp: .now,
            aiMealEntryId: aiEntryId
        )
        todayLog.foodEntries.append(foodEntry)

        // 2. AI Meal Entry for the Editorial Screen
        let aiEntry = AIMealEntry(
            id: aiEntryId,
            title: parsed.title,
            location: "Logged with Soma AI",
            storyText: originalText,
            calories: parsed.calories,
            proteinG: parsed.proteinG,
            carbsG: parsed.carbsG,
            fatG: parsed.fatG,
            photoDataList: photos,
            voiceAudioRelativePath: audioRelativePath,
            voiceWaveformSamples: waveformSamples,
            voiceDurationSeconds: audioRelativePath != nil ? Double(waveformSamples.count) * 0.06 : 0.0,
            breakdownNotes: parsed.summary
        )
        aiEntry.dailyLog = todayLog
        modelContext.insert(aiEntry)

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(parsed.summary)
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
