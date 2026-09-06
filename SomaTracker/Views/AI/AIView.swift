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
                if !aiEntries.isEmpty {
                    Section {
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

                            Text("\(aiEntries.count) Entries")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 14, leading: 22, bottom: 4, trailing: 22))
                        .listRowBackground(Color.clear)
                    }
                }

                // 3. Floating Tab Bar Clearance
                Section {
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
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Voice & Food Intelligence")
                .font(.system(size: 22, weight: .bold, design: .default))
                .foregroundStyle(Color(.label))

            Text("Speak, snap, or type to log meals, macros, and hydration instantly.")
                .font(.system(size: 14))
                .foregroundStyle(Color(.secondaryLabel))
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

                    Text("On-Device Speech")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(.tertiaryLabel))
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
                            Text("Listening... Speak what you ate or drank (tap red square to log)")
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
                        Text("Tap the red record button to speak, or snap a photo of your meal.")
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
                    showCameraCapture = true
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
        if let relPath = entry.voiceAudioRelativePath {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(relPath))
        }

        withAnimation(.snappy(duration: 0.25)) {
            modelContext.delete(entry)
            try? modelContext.save()
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

            // Guard against micro-taps (< 0.5s)
            guard result.duration >= 0.5 else {
                showToast("Recording too short. Speak and tap to stop.")
                return
            }

            var effectiveSpeech = !result.text.isEmpty
                ? result.text
                : speechService.liveTranscribedText

            Task {
                // If live transcription is empty, attempt file transcription
                if effectiveSpeech.isEmpty, let url = result.audioURL {
                    let fileTranscribed = await speechService.transcribeAudioFile(at: url)
                    if !fileTranscribed.isEmpty {
                        effectiveSpeech = fileTranscribed
                    }
                }

                if !effectiveSpeech.isEmpty || result.audioURL != nil {
                    await MainActor.run {
                        showToast("Analyzing meal with Soma AI...")
                    }

                    // Parse speech or audio via AI Router (uses Gemini Flash if configured, or FoodNutritionDatabase)
                    let analysis = await AIRouter.shared.processMultimodalMeal(
                        notes: nil,
                        photos: [],
                        audioURL: result.audioURL,
                        directTranscription: effectiveSpeech.isEmpty ? nil : effectiveSpeech
                    )

                    let finalLocation = await resolveMealLocation(from: analysis.location)

                    await MainActor.run {
                        let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)

                        let story = !analysis.storyNarrative.isEmpty
                            ? analysis.storyNarrative
                            : (!effectiveSpeech.isEmpty ? effectiveSpeech : analysis.title)

                        let parsedWaterCheck = FoodNutritionDatabase.shared.parseInput(story)
                        if parsedWaterCheck.isWater {
                            let water = WaterEntry(amount: parsedWaterCheck.waterML, timestamp: .now, label: "AI Voice Log")
                            todayLog.waterEntries.append(water)
                            try? modelContext.save()
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
                            timestamp: .now
                        )
                        todayLog.foodEntries.append(foodEntry)

                        let aiEntry = AIMealEntry(
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

                        try? modelContext.save()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showToast("Logged \(analysis.title) · \(analysis.calories) kcal")
                        selectedEntryForDetail = aiEntry
                    }
                } else {
                    await MainActor.run {
                        showToast("No audio detected. Please try speaking again.")
                    }
                }
            }

        } else {
            // START RECORDING
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

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        inputText = ""
        isInputFocused = false

        Task {
            let analysis = await AIRouter.shared.processMultimodalMeal(
                notes: query,
                photos: [],
                audioURL: nil
            )

            let finalLocation = await resolveMealLocation(from: analysis.location)

            await MainActor.run {
                let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)

                let parsedWaterCheck = FoodNutritionDatabase.shared.parseInput(query)
                if parsedWaterCheck.isWater {
                    let water = WaterEntry(amount: parsedWaterCheck.waterML, timestamp: .now, label: "AI Log")
                    todayLog.waterEntries.append(water)
                    try? modelContext.save()
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
                    mealType: "AI Log",
                    timestamp: .now
                )
                todayLog.foodEntries.append(foodEntry)

                let aiEntry = AIMealEntry(
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

                try? modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast("Logged \(analysis.title) · \(analysis.calories) kcal")
            }
        }
    }

    private func handleCapturedPhoto(_ image: UIImage) {
        capturedImage = nil
        guard let jpegData = image.jpegData(compressionQuality: 0.82) else { return }

        showToast("Analyzing meal photo...")

        Task {
            let analysis = await AIRouter.shared.processMultimodalMeal(
                notes: "Meal Photo",
                photos: [jpegData],
                audioURL: nil
            )

            let finalLocation = await resolveMealLocation(from: analysis.location)

            await MainActor.run {
                let todayLog = DailyLog.fetchOrCreateToday(context: modelContext)

                let foodEntry = FoodEntry(
                    name: analysis.title,
                    calories: analysis.calories,
                    proteinG: analysis.proteinG,
                    carbsG: analysis.carbsG,
                    fatG: analysis.fatG,
                    mealType: "Photo Log",
                    timestamp: .now
                )
                todayLog.foodEntries.append(foodEntry)

                let aiEntry = AIMealEntry(
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

                try? modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast("Logged \(analysis.title) · \(analysis.calories) kcal")

                selectedEntryForDetail = aiEntry
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

        if parsed.isWater {
            let water = WaterEntry(amount: parsed.waterML, timestamp: .now, label: "AI Voice Log")
            todayLog.waterEntries.append(water)
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
            timestamp: .now
        )
        todayLog.foodEntries.append(foodEntry)

        // 2. AI Meal Entry for the Editorial Screen
        let aiEntry = AIMealEntry(
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

#Preview {
    NavigationStack {
        AIView()
    }
    .modelContainer(PreviewData.container)
}
