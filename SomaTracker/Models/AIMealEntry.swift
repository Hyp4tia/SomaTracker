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
        // If an entry already exists for this AI meal, update it instead of duplicating
        if let existing = log.foodEntries.first(where: { $0.aiMealEntryId == self.id }) {
            existing.name = title.isEmpty ? "AI Meal" : title
            existing.calories = calories
            existing.proteinG = proteinG
            existing.carbsG = carbsG
            existing.fatG = fatG
            existing.timestamp = timestamp
            self.dailyLog = log
            try? context.save()
            return existing
        }

        let entry = FoodEntry(
            name: title.isEmpty ? "AI Meal" : title,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            mealType: "AI Log",
            timestamp: timestamp,
            aiMealEntryId: self.id
        )
        log.foodEntries.append(entry)
        self.dailyLog = log
        try? context.save()
        return entry
    }
}

extension AIMealEntry {
    /// Deletes the AI meal entry, cleans up the on-disk voice audio file,
    /// and deletes any linked FoodEntry or WaterEntry in DailyLog.
    func deleteWithSyncedEntries(in context: ModelContext) {
        // 1. Remove voice audio file from disk
        if let relPath = voiceAudioRelativePath {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(relPath))
        }

        let currentId = self.id
        let mealTimestamp = self.timestamp
        let mealCalories = self.calories
        let mealTitle = self.title

        // 2. Locate and delete corresponding FoodEntry from DailyLog
        let foodDescriptor = FetchDescriptor<FoodEntry>()
        if let foods = try? context.fetch(foodDescriptor) {
            for food in foods {
                let isMatchById = (food.aiMealEntryId == currentId)
                let isMatchByHeuristic = (food.aiMealEntryId == nil) &&
                    (food.mealType.contains("AI") || food.mealType.contains("Voice") || food.mealType.contains("Photo")) &&
                    abs(food.timestamp.timeIntervalSince(mealTimestamp)) < 120 &&
                    food.calories == mealCalories &&
                    (food.name == mealTitle || mealTitle.contains("AI Meal") || food.name.contains("AI Meal"))

                if isMatchById || isMatchByHeuristic {
                    food.dailyLog?.foodEntries.removeAll { $0.id == food.id }
                    context.delete(food)
                }
            }
        }

        // 3. Locate and delete corresponding WaterEntry from DailyLog
        let waterDescriptor = FetchDescriptor<WaterEntry>()
        if let waters = try? context.fetch(waterDescriptor) {
            for water in waters {
                let isMatchById = (water.aiMealEntryId == currentId)
                let isMatchByHeuristic = (water.aiMealEntryId == nil) &&
                    (water.label?.contains("AI") == true) &&
                    abs(water.timestamp.timeIntervalSince(mealTimestamp)) < 120 &&
                    (mealTitle.contains("Hydration") || mealTitle.contains("Water"))

                if isMatchById || isMatchByHeuristic {
                    water.dailyLog?.waterEntries.removeAll { $0.id == water.id }
                    context.delete(water)
                }
            }
        }

        // 4. Delete the AIMealEntry itself
        context.delete(self)
        try? context.save()
    }
}
