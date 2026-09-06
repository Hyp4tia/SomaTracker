//
//  AIMealEntry.swift
//  SomaTracker
//
//  SwiftData Model representing a multimodal AI-logged meal or event entry.
//

import Foundation
import SwiftData

@Model
final class AIMealEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var title: String = ""
    var location: String = ""
    var storyText: String = ""
    var calories: Int = 0
    var proteinG: Double = 0.0
    var carbsG: Double = 0.0
    var fatG: Double = 0.0

    // Store up to 5 photos as binary Data
    @Attribute(.externalStorage)
    var photoDataList: [Data] = []

    // Voice note metadata
    var voiceAudioRelativePath: String? = nil
    var voiceWaveformSamples: [Float] = []
    var voiceDurationSeconds: Double = 0.0

    var isBookmarked: Bool = false
    var confidenceScore: Double = 0.95
    var breakdownNotes: String = ""

    var dailyLog: DailyLog? = nil

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        title: String,
        location: String = "",
        storyText: String = "",
        calories: Int = 0,
        proteinG: Double = 0.0,
        carbsG: Double = 0.0,
        fatG: Double = 0.0,
        photoDataList: [Data] = [],
        voiceAudioRelativePath: String? = nil,
        voiceWaveformSamples: [Float] = [],
        voiceDurationSeconds: Double = 0.0,
        isBookmarked: Bool = false,
        breakdownNotes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.location = location
        self.storyText = storyText
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.photoDataList = photoDataList
        self.voiceAudioRelativePath = voiceAudioRelativePath
        self.voiceWaveformSamples = voiceWaveformSamples
        self.voiceDurationSeconds = voiceDurationSeconds
        self.isBookmarked = isBookmarked
        self.breakdownNotes = breakdownNotes
    }

    /// Converts this AI meal entry into a standard FoodEntry in the user's DailyLog
    @discardableResult
    func syncToFoodEntry(in context: ModelContext) -> FoodEntry {
        let log = dailyLog ?? DailyLog.fetchOrCreateToday(context: context)
        let entry = FoodEntry(
            name: title.isEmpty ? "AI Meal" : title,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            mealType: "AI Log",
            timestamp: timestamp
        )
        log.foodEntries.append(entry)
        self.dailyLog = log
        try? context.save()
        return entry
    }
}
