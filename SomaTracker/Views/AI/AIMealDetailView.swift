//
//  AIMealDetailView.swift
//  SomaTracker
//
//  Editorial AI Meal & Memory Detail View faithfully recreating the user's mockup.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AIMealDetailView: View {
    @Bindable var entry: AIMealEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var playbackService = AudioPlaybackService()
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showShareSheet = false
    @State private var showLoggedToast = false
    @State private var showEditDetailsSheet = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    private var hasValidVoiceAudio: Bool {
        guard let relPath = entry.voiceAudioRelativePath, !relPath.isEmpty else { return false }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs.appendingPathComponent(relPath)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    private var voiceDurationDisplay: String {
        if playbackService.isPlaying || playbackService.currentTime > 0 {
            return playbackService.timeRemainingString
        } else if entry.voiceDurationSeconds > 0 {
            let total = entry.voiceDurationSeconds
            let mins = Int(total) / 60
            let secs = Int(total) % 60
            return String(format: "-%d:%02d", mins, secs)
        } else {
            return "0:00"
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Photo Carousel
                    MediaCarouselView(photos: entry.photoDataList)
                        .padding(.top, 8)
                        .padding(.horizontal, 20)

                    // 2. Metadata Header Lockup
                    VStack(spacing: 6) {
                        Text(dateFormatter.string(from: entry.timestamp))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(.secondaryLabel))
                            .textCase(.none)

                        Text(entry.title.isEmpty ? "Jacob's Wedding" : entry.title)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(Color(.label))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        if !entry.location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 13))
                                Text(entry.location)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(Color(.secondaryLabel))
                        }
                    }
                    .padding(.top, 4)

                    // 3. Narrative / Story Text
                    if !entry.storyText.isEmpty {
                        Text(entry.storyText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(.label))
                            .lineSpacing(5)
                            .multilineTextAlignment(isArabic(entry.storyText) ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: isArabic(entry.storyText) ? .trailing : .leading)
                            .padding(.horizontal, 24)
                    }

                    // 4. Voice Note Player Section (Only shown if real audio file was recorded and exists)
                    if hasValidVoiceAudio {
                        voiceNoteSection
                            .padding(.horizontal, 24)
                            .padding(.top, 4)
                    }

                    // 5. Nutritional Breakdown & Threads Section
                    nutritionThreadsSection
                        .padding(.horizontal, 24)
                        .padding(.top, 6)

                    // Bottom clearance for floating action dock
                    Spacer()
                        .frame(height: 120)
                }
            }
            .scrollIndicators(.hidden)

            // 6. Floating Action Dock (Matching Mockup)
            FloatingActionDock(
                isBookmarked: entry.isBookmarked,
                onLogTap: { logToDailyTracker() },
                onPhotosTap: { showPhotosPicker = true },
                onShareTap: { showShareSheet = true },
                onBookmarkTap: { toggleBookmark() }
            )
            .padding(.bottom, 24)

            // Success Toast Overlay
            if showLoggedToast {
                loggedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    playbackService.stop()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(.label))
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Back")
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        // Collaborator / Share action
                        showShareSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(.label))
                    }

                    Divider()
                        .frame(height: 12)

                    Menu {
                        Button("Edit Details", systemImage: "pencil") {
                            showEditDetailsSheet = true
                        }
                        Button(entry.isBookmarked ? "Remove Bookmark" : "Bookmark", systemImage: entry.isBookmarked ? "bookmark.slash" : "bookmark") {
                            toggleBookmark()
                        }
                        Button("Delete Entry", systemImage: "trash", role: .destructive) {
                            deleteEntry()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(.label))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
        }
        .onAppear {
            if hasValidVoiceAudio, let relPath = entry.voiceAudioRelativePath {
                playbackService.loadAudio(relativePath: relPath)
            }
        }
        .onDisappear {
            playbackService.stop()
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotoItems) { _, items in
            loadNewPhotos(from: items)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareableText])
        }
        .sheet(isPresented: $showEditDetailsSheet) {
            editDetailsModal
        }
        .enableNativeSwipeToGoBack()
    }

    // MARK: - Voice Note Section

    private var voiceNoteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Voice note")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(.label))

            HStack(spacing: 14) {
                // Play / Pause Circle Button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    playbackService.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(SomaColors.navy)
                            .frame(width: 44, height: 44)

                        Image(systemName: playbackService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(SomaColors.white)
                            .offset(x: playbackService.isPlaying ? 0 : 1.5)
                    }
                }
                .buttonStyle(.plain)

                // Interactive Audio Waveform
                AudioWaveformView(
                    samples: entry.voiceWaveformSamples,
                    progress: playbackService.progress,
                    onSeek: { percentage in
                        playbackService.seek(to: percentage)
                    }
                )
                .frame(height: 32)

                // Countdown Timer (e.g. -0:28)
                Text(voiceDurationDisplay)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(.secondaryLabel))
                    .frame(minWidth: 46, alignment: .trailing)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Nutrition & Threads Section

    private var nutritionThreadsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nutritional Breakdown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(.label))

                Spacer()

                Text("AI Verified")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SomaColors.emerald)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SomaColors.emerald.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Macro Lockup
            HStack(spacing: 8) {
                macroChip(label: "Calories", value: "\(entry.calories)", unit: "kcal", color: SomaColors.coral)
                macroChip(label: "Protein", value: "\(Int(entry.proteinG))", unit: "g", color: SomaColors.iris)
                macroChip(label: "Carbs", value: "\(Int(entry.carbsG))", unit: "g", color: SomaColors.amber)
                macroChip(label: "Fat", value: "\(Int(entry.fatG))", unit: "g", color: SomaColors.teal)
            }

            // Threads / Story Commentary Preview
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(SomaColors.navy)
                        .frame(width: 34, height: 34)

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SomaColors.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Soma AI")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.label))

                        Text("Just now")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }

                    Text("Macros estimated based on ingredients and portion visual analysis.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func macroChip(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))

            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Actions & Helpers

    private func logToDailyTracker() {
        entry.syncToFoodEntry(in: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showLoggedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showLoggedToast = false
            }
        }
    }

    private func toggleBookmark() {
        entry.isBookmarked.toggle()
        try? modelContext.save()
    }

    private func deleteEntry() {
        playbackService.stop()
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }

    private func isArabic(_ text: String) -> Bool {
        text.range(of: "\\p{Arabic}", options: .regularExpression) != nil
    }

    private func loadNewPhotos(from items: [PhotosPickerItem]) {
        Task {
            var newDatas: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    newDatas.append(data)
                }
            }
            await MainActor.run {
                entry.photoDataList.append(contentsOf: newDatas)
                try? modelContext.save()
                selectedPhotoItems = []
            }
        }
    }

    private var shareableText: String {
        """
        \(entry.title) - \(dateFormatter.string(from: entry.timestamp))
        \(entry.location.isEmpty ? "" : "📍 \(entry.location)\n")
        \(entry.storyText)

        Nutrition: \(entry.calories) kcal | \(Int(entry.proteinG))g Protein | \(Int(entry.carbsG))g Carbs | \(Int(entry.fatG))g Fat
        Logged with Soma AI
        """
    }

    private var loggedToast: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SomaColors.emerald)
                Text("Added to Daily Log")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.label))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
            )
            .padding(.top, 16)

            Spacer()
        }
    }

    private var editDetailsModal: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $entry.title)
                    TextField("Location", text: $entry.location)
                    TextField("Story Notes", text: $entry.storyText, axis: .vertical)
                }

                Section("Nutrition") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("kcal", value: $entry.calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("g", value: $entry.proteinG, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        showEditDetailsSheet = false
                    }
                    .font(.headline)
                }
            }
        }
    }
}

// Lightweight UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let sample = AIMealEntry(
        title: "Jacob's Wedding",
        location: "Los Angeles, CA",
        storyText: "We were not on the guest list and made no real effort to pretend otherwise. They fed us anyway lol.",
        calories: 680,
        proteinG: 38.0,
        carbsG: 62.0,
        fatG: 24.0,
        voiceDurationSeconds: 28.0
    )

    NavigationStack {
        AIMealDetailView(entry: sample)
    }
    .modelContainer(PreviewData.container)
}
