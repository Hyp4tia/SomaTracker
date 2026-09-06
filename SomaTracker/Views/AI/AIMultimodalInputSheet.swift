//
//  AIMultimodalInputSheet.swift
//  SomaTracker
//
//  Multimodal capture sheet for snapping photos, recording voice notes, and typing notes.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AIMultimodalInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var notesText: String = ""
    @State private var selectedPhotos: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    // Audio recording state
    @State private var recordingService = AudioRecordingService()
    @State private var recordedAudioURL: URL? = nil
    @State private var recordedRelativePath: String? = nil
    @State private var recordedWaveformSamples: [Float] = []
    @State private var recordedDuration: TimeInterval = 0

    // Loading & Processing state
    @State private var isAnalyzing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var createdEntry: AIMealEntry? = nil

    var onEntryCreated: ((AIMealEntry) -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header prompt
                    VStack(spacing: 6) {
                        Text("Soma Multimodal AI")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(Color(.label))

                        Text("Speak, snap photos, or describe your meal. Siri AI & Gemini will analyze nutrition automatically.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(.secondaryLabel))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 12)

                    // 1. Photos Section
                    photosSection

                    // 2. Voice Note Recording Section
                    voiceRecordingSection

                    // 3. Text Notes Section
                    notesSection

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // 4. Primary Action Button
                    Button {
                        analyzeAndSave()
                    } label: {
                        HStack(spacing: 8) {
                            if isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                                Text("Analyzing Nutrition...")
                                    .font(SomaTypography.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .bold))
                                Text("Analyze with Soma AI")
                                    .font(SomaTypography.body.weight(.semibold))
                            }
                        }
                        .foregroundStyle(SomaColors.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canAnalyze ? SomaColors.navy : Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canAnalyze || isAnalyzing)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New AI Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if recordingService.isRecording {
                            recordingService.cancelRecording()
                        }
                        dismiss()
                    }
                }
            }
        }
    }

    private var canAnalyze: Bool {
        !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !selectedPhotos.isEmpty ||
        recordedAudioURL != nil ||
        recordingService.isRecording
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Photos (Up to 5)", systemImage: "photo.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))

                Spacer()

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Photos")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SomaColors.navy)
                }
            }
            .padding(.horizontal, 20)

            if !selectedPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<selectedPhotos.count, id: \.self) { idx in
                            if let uiImg = UIImage(data: selectedPhotos[idx]) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    Button {
                                        selectedPhotos.remove(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(.white, Color.black.opacity(0.6))
                                            .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task {
                var newPhotos: [Data] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        newPhotos.append(data)
                    }
                }
                await MainActor.run {
                    self.selectedPhotos = newPhotos
                }
            }
        }
    }

    // MARK: - Voice Recording Section

    private var voiceRecordingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Voice Note", systemImage: "waveform")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.horizontal, 20)

            HStack(spacing: 14) {
                Button {
                    handleVoiceButtonTap()
                } label: {
                    ZStack {
                        Circle()
                            .fill(recordingService.isRecording ? Color.red : SomaColors.navy)
                            .frame(width: 48, height: 48)

                        Image(systemName: recordingService.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)

                if recordingService.isRecording {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recording voice note...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.red)

                        AudioWaveformView(samples: recordingService.waveformSamples, progress: 1.0)
                            .frame(height: 24)
                    }
                } else if recordedAudioURL != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Voice note captured")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(.label))

                            Spacer()

                            Button("Delete") {
                                recordedAudioURL = nil
                                recordedRelativePath = nil
                                recordedWaveformSamples = []
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                        }

                        AudioWaveformView(samples: recordedWaveformSamples, progress: 0.0)
                            .frame(height: 24)
                    }
                } else {
                    Text("Tap to record what you ate or notes...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(.placeholderText))
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes & Location (Optional)", systemImage: "note.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.horizontal, 20)

            TextField(
                "e.g. Jacob's Wedding in Los Angeles, CA. Sourdough toast, salmon bowl, iced latte...",
                text: $notesText,
                axis: .vertical
            )
            .lineLimit(3...5)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Voice Handling

    private func handleVoiceButtonTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if recordingService.isRecording {
            if let result = recordingService.stopRecording() {
                self.recordedAudioURL = result.url
                self.recordedRelativePath = result.relativePath
                self.recordedWaveformSamples = result.samples
                self.recordedDuration = result.duration
            }
        } else {
            Task {
                let granted = await recordingService.requestPermission()
                if granted {
                    await MainActor.run {
                        _ = recordingService.startRecording()
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Microphone permission is required to record voice notes."
                    }
                }
            }
        }
    }

    // MARK: - Analysis & Save

    private func analyzeAndSave() {
        if recordingService.isRecording {
            if let result = recordingService.stopRecording() {
                self.recordedAudioURL = result.url
                self.recordedRelativePath = result.relativePath
                self.recordedWaveformSamples = result.samples
                self.recordedDuration = result.duration
            }
        }

        isAnalyzing = true
        errorMessage = nil

        Task {
            let result = await AIRouter.shared.processMultimodalMeal(
                notes: notesText.isEmpty ? nil : notesText,
                photos: selectedPhotos,
                audioURL: recordedAudioURL
            )

            await MainActor.run {
                isAnalyzing = false

                let newEntry = AIMealEntry(
                    title: result.title,
                    location: result.location,
                    storyText: result.storyNarrative,
                    calories: result.calories,
                    proteinG: result.proteinG,
                    carbsG: result.carbsG,
                    fatG: result.fatG,
                    photoDataList: selectedPhotos,
                    voiceAudioRelativePath: recordedRelativePath,
                    voiceWaveformSamples: recordedWaveformSamples,
                    voiceDurationSeconds: recordedDuration
                )

                modelContext.insert(newEntry)
                try? modelContext.save()

                onEntryCreated?(newEntry)
                dismiss()
            }
        }
    }
}
