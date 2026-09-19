//
//  SomaLogWriter.swift
//  SomaTracker
//
//  The one place a chat log becomes journal entries.
//
//  TODO: the AI tab still writes through its own three paths. Moving them onto this writer so there is
//  exactly one write path is a follow-up of its own, with its own verification, because those paths are
//  the app's busiest code and this feature must not disturb them.
//

import Foundation
import SwiftData

enum SomaLogWriter {
    struct Written {
        let foodEntry: FoodEntry
        let aiEntry: AIMealEntry
        let dailyLog: DailyLog
    }

    /// Writes a meal analysis into today's log. Returns nil when the store refuses the write, so the
    /// caller can say so instead of showing a success that did not happen.
    static func writeMeal(
        _ analysis: AIMealAnalysisResult,
        photos: [Data],
        voiceRelativePath: String? = nil,
        voiceWaveformSamples: [Float] = [],
        voiceDuration: TimeInterval = 0,
        mealType: String,
        context: ModelContext
    ) -> Written? {
        let todayLog = DailyLog.fetchOrCreateToday(context: context)
        let aiEntryId = UUID()

        let foodEntry = FoodEntry(
            name: analysis.title,
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            mealType: mealType,
            timestamp: .now,
            aiMealEntryId: aiEntryId
        )
        todayLog.foodEntries.append(foodEntry)

        let aiEntry = AIMealEntry(
            id: aiEntryId,
            title: analysis.title,
            location: analysis.location,
            storyText: analysis.storyNarrative,
            calories: analysis.calories,
            proteinG: analysis.proteinG,
            carbsG: analysis.carbsG,
            fatG: analysis.fatG,
            photoDataList: photos,
            voiceAudioRelativePath: voiceRelativePath,
            voiceWaveformSamples: voiceWaveformSamples,
            voiceDurationSeconds: voiceDuration,
            breakdownNotes: analysis.storyNarrative
        )
        aiEntry.dailyLog = todayLog
        context.insert(aiEntry)

        // A log can name a drink and a meal in one breath. The water rides along in the same save.
        if let water = WaterEntry.loggedWithMeal(analysis.waterML, linkedTo: aiEntryId) {
            todayLog.waterEntries.append(water)
        }

        do {
            try context.save()
        } catch {
            print("[SomaChat] Couldn't save the log: \(error.localizedDescription)")
            return nil
        }

        return Written(foodEntry: foodEntry, aiEntry: aiEntry, dailyLog: todayLog)
    }
}
